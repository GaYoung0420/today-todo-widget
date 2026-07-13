import Foundation
import Observation

@MainActor
@Observable
final class TodoStore {
    var todos: [TodoItem] = []
    var selectedTodoID: TodoItem.ID?
    var blockedSites: [String] = []
    var newTodoTitle = ""
    var newBlockedSite = ""
    var isBlockedSitesPresented = false
    var defaultPomodoroMinutes = 25
    var defaultBreakMinutes = 5
    var launchAtLogin = false
    var notificationsEnabled = true
    var selectedFocusMusicID: String?
    var todoWidgetPosition: WidgetPosition?
    var isTodoWidgetPositionLocked = false
    var isTodoWidgetDesktopModeEnabled = true
    var selectedDate = Date()
    var notionEnabled = false
    var notionDatabaseID = ""
    var notionToken = ""
    var notionLastSyncedAt: Date?
    var notionSyncMessage = ""
    var isNotionSyncing = false
    var notionAutoSyncEnabled = true
    var notionAutoSyncIntervalSeconds = 60

    private let persistenceURL: URL
    private let notionClient = NotionTodoClient()
    private let notionTokenAccount = "notionIntegrationToken"
    private var notionSyncTasks: [TodoItem.ID: Task<Void, Never>] = [:]
    private var notionAutoSyncTimer: Timer?

    init() {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("FocusTodo", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )

        persistenceURL = supportDirectory.appendingPathComponent("state.json")
        load()
        notionToken = KeychainStore.string(for: notionTokenAccount)
    }

    var selectedTodo: TodoItem? {
        let visibleTodos = todosForSelectedDate
        guard let selectedTodoID else { return visibleTodos.first ?? todos.first }
        return visibleTodos.first { $0.id == selectedTodoID } ?? visibleTodos.first ?? todos.first
    }

    var todosForSelectedDate: [TodoItem] {
        todos.filter { Calendar.current.isDate($0.todoDate, inSameDayAs: selectedDate) }
    }

    var completedTodosForSelectedDateCount: Int {
        todosForSelectedDate.filter(\.isDone).count
    }

    var canManuallySyncNotion: Bool {
        notionEnabled
    }

    var notionWidgetSyncText: String {
        if !notionEnabled {
            return "노션 꺼짐"
        }
        if notionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "토큰 필요"
        }
        if notionDatabaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "DB 필요"
        }
        if isNotionSyncing {
            return "동기화 중"
        }
        if notionSyncMessage.contains("실패") ||
            notionSyncMessage.contains("오류") ||
            notionSyncMessage.contains("찾을 수 없습니다") ||
            notionSyncMessage.contains("invalid") ||
            notionSyncMessage.contains("unauthorized") {
            return "동기화 실패"
        }
        if let notionLastSyncedAt {
            return "\(Formatters.relativeTime(notionLastSyncedAt)) 동기화"
        }
        return "동기화 대기"
    }

    func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let todo = insertNewTodo(title: title)
        scheduleNotionUpsert(todo, delayNanoseconds: 0)
        newTodoTitle = ""
    }

    @discardableResult
    func addQuickMemoTodo() -> TodoItem {
        let todo = insertNewTodo(title: nextQuickMemoTodoTitle())
        scheduleNotionUpsert(todo, delayNanoseconds: 0)
        return todo
    }

    @discardableResult
    private func insertNewTodo(title: String) -> TodoItem {
        let todo = TodoItem(
            title: title,
            pomodoroMinutes: defaultPomodoroMinutes,
            breakMinutes: defaultBreakMinutes,
            todoDate: selectedDate
        )
        todos.insert(todo, at: 0)
        selectedTodoID = todo.id
        save()
        return todo
    }

    private func nextQuickMemoTodoTitle() -> String {
        let baseTitle = "새 투두"
        let existingTitles = Set(todos.map(\.title))
        guard existingTitles.contains(baseTitle) else { return baseTitle }

        var index = 2
        while existingTitles.contains("\(baseTitle) \(index)") {
            index += 1
        }
        return "\(baseTitle) \(index)"
    }

    func deleteTodo(_ todo: TodoItem) {
        let notionPageID = todo.notionPageID
        todos.removeAll { $0.id == todo.id }
        if selectedTodoID == todo.id {
            selectedTodoID = todos.first?.id
        }
        save()
        if let notionPageID {
            archiveNotionTodo(pageID: notionPageID)
        }
    }

    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = normalized(todo)
        save()
        scheduleNotionUpsert(todos[index])
    }

    func toggleDone(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index].isDone.toggle()
        todos[index].status = todos[index].isDone ? .completed : .notStarted
        save()
        scheduleNotionUpsert(todos[index])
    }

    @discardableResult
    func startPomodoro(for todo: TodoItem) -> TodoItem {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return todo }
        todos[index].isDone = false
        todos[index].status = .inProgress
        save()
        scheduleNotionUpsert(todos[index], delayNanoseconds: 0)
        return todos[index]
    }

    func moveTodo(draggedID: TodoItem.ID, before targetID: TodoItem.ID) {
        guard let targetIndex = todos.firstIndex(where: { $0.id == targetID }) else { return }
        moveTodo(draggedID: draggedID, to: targetIndex)
    }

    func moveTodo(draggedID: TodoItem.ID, after targetID: TodoItem.ID) {
        guard let targetIndex = todos.firstIndex(where: { $0.id == targetID }) else { return }
        moveTodo(draggedID: draggedID, to: targetIndex + 1)
    }

    func moveTodoToEnd(draggedID: TodoItem.ID) {
        moveTodo(draggedID: draggedID, to: todos.count)
    }

    private func moveTodo(draggedID: TodoItem.ID, to destinationIndex: Int) {
        guard let sourceIndex = todos.firstIndex(where: { $0.id == draggedID }) else { return }

        let clampedDestination = min(max(destinationIndex, 0), todos.count)
        let adjustedDestination = sourceIndex < clampedDestination ? clampedDestination - 1 : clampedDestination
        guard adjustedDestination != sourceIndex else { return }

        let draggedTodo = todos.remove(at: sourceIndex)
        todos.insert(draggedTodo, at: adjustedDestination)
        save()
    }

    func completePomodoro(for todo: TodoItem) -> TodoItem {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return todo }
        todos[index].completedPomodoros += 1
        save()
        return todos[index]
    }

    func binding(for todo: TodoItem) -> TodoItem {
        todos.first { $0.id == todo.id } ?? todo
    }

    func addBlockedSite() {
        let site = newBlockedSite
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        guard !site.isEmpty, !blockedSites.contains(site) else { return }
        blockedSites.append(site)
        blockedSites.sort()
        newBlockedSite = ""
        save()
    }

    func deleteBlockedSite(_ site: String) {
        blockedSites.removeAll { $0 == site }
        save()
    }

    func setDefaultPomodoroMinutes(_ minutes: Int) {
        defaultPomodoroMinutes = minutes
        todos = todos.map {
            var todo = $0
            todo.pomodoroMinutes = minutes
            return todo
        }
        save()
    }

    func setDefaultBreakMinutes(_ minutes: Int) {
        defaultBreakMinutes = minutes
        todos = todos.map {
            var todo = $0
            todo.breakMinutes = minutes
            return todo
        }
        save()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        save()
    }

    func setSelectedFocusMusic(_ track: FocusMusicTrack?) {
        selectedFocusMusicID = track?.id
        save()
    }

    func setTodoWidgetPosition(x: Double, y: Double) {
        todoWidgetPosition = WidgetPosition(x: x, y: y)
        save()
    }

    func setTodoWidgetPositionLocked(_ locked: Bool) {
        isTodoWidgetPositionLocked = locked
        save()
    }

    func setTodoWidgetDesktopModeEnabled(_ enabled: Bool) {
        isTodoWidgetDesktopModeEnabled = enabled
        save()
    }

    func moveSelectedDate(byDays days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = date
        selectedTodoID = todosForSelectedDate.first?.id
        refreshNotionTodosIfStale(maxAgeSeconds: 30)
    }

    func selectToday() {
        selectedDate = Date()
        selectedTodoID = todosForSelectedDate.first?.id
        refreshNotionTodosIfStale(maxAgeSeconds: 30)
    }

    func setNotionEnabled(_ enabled: Bool) {
        notionEnabled = enabled
        saveNotionSettings()
        configureNotionAutoSync()
    }

    func setNotionAutoSyncEnabled(_ enabled: Bool) {
        notionAutoSyncEnabled = enabled
        save()
        configureNotionAutoSync()
    }

    func setNotionAutoSyncIntervalSeconds(_ seconds: Int) {
        notionAutoSyncIntervalSeconds = max(seconds, 30)
        save()
        configureNotionAutoSync()
    }

    func saveNotionSettings() {
        notionDatabaseID = notionDatabaseID.trimmingCharacters(in: .whitespacesAndNewlines)
        notionToken = notionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let didSaveToken = KeychainStore.setString(notionToken, for: notionTokenAccount)
        if !notionToken.isEmpty, !didSaveToken {
            notionSyncMessage = "토큰을 키체인에 저장하지 못했습니다. 다시 저장해주세요."
        }
        save()
    }

    func refreshNotionTodosNow() {
        saveNotionSettings()
        configureNotionAutoSync()
        Task { @MainActor in
            await refreshNotionTodos()
        }
    }

    func refreshNotionTodosIfStale(maxAgeSeconds: TimeInterval) {
        guard canSyncNotion, !isNotionSyncing else { return }

        if let notionLastSyncedAt,
           Date().timeIntervalSince(notionLastSyncedAt) < maxAgeSeconds {
            return
        }

        refreshNotionTodosNow()
    }

    func configureNotionAutoSync() {
        notionAutoSyncTimer?.invalidate()
        notionAutoSyncTimer = nil

        guard canSyncNotion, notionAutoSyncEnabled else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(notionAutoSyncIntervalSeconds), repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isNotionSyncing else { return }
                await self.refreshNotionTodos(silent: true)
            }
        }
        timer.tolerance = min(TimeInterval(notionAutoSyncIntervalSeconds) * 0.15, 10)
        notionAutoSyncTimer = timer
    }

    func refreshNotionTodos() async {
        await refreshNotionTodos(silent: false)
    }

    func refreshNotionTodos(silent: Bool) async {
        saveNotionSettings()

        guard notionEnabled else {
            if !silent {
                notionSyncMessage = "노션 연동이 꺼져 있습니다."
            }
            save()
            return
        }

        guard !notionToken.isEmpty, !notionDatabaseID.isEmpty else {
            notionSyncMessage = "토큰과 DB URL/ID를 입력해주세요."
            save()
            return
        }

        guard !isNotionSyncing else { return }

        isNotionSyncing = true
        if !silent {
            notionSyncMessage = "노션에서 가져오는 중..."
        }
        defer { isNotionSyncing = false }

        do {
            let notionTodos = try await notionClient.fetchTodos(
                token: notionToken,
                databaseOrDataSourceID: notionDatabaseID,
                defaultPomodoroMinutes: defaultPomodoroMinutes,
                defaultBreakMinutes: defaultBreakMinutes
            )
            mergeNotionTodos(notionTodos)
            notionLastSyncedAt = Date()
            let syncedDayCount = Set(notionTodos.map { Calendar.current.startOfDay(for: $0.todoDate) }).count
            notionSyncMessage = "\(notionTodos.count)개 항목을 \(syncedDayCount)개 날짜에 동기화했습니다."
            save()
        } catch {
            notionSyncMessage = error.localizedDescription
            save()
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: persistenceURL) else {
            apply(AppState.initial)
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(AppState.self, from: data)
            apply(state)
            if needsTimerMigration(state) {
                save()
            }
        } catch {
            apply(AppState.initial)
        }
    }

    func save() {
        let state = AppState(
            todos: todos,
            blockedSites: blockedSites,
            defaultPomodoroMinutes: defaultPomodoroMinutes,
            defaultBreakMinutes: defaultBreakMinutes,
            launchAtLogin: launchAtLogin,
            notificationsEnabled: notificationsEnabled,
            selectedFocusMusicID: selectedFocusMusicID,
            todoWidgetPosition: todoWidgetPosition,
            isTodoWidgetPositionLocked: isTodoWidgetPositionLocked,
            isTodoWidgetDesktopModeEnabled: isTodoWidgetDesktopModeEnabled,
            notionEnabled: notionEnabled,
            notionDatabaseID: notionDatabaseID,
            notionLastSyncedAt: notionLastSyncedAt,
            notionAutoSyncEnabled: notionAutoSyncEnabled,
            notionAutoSyncIntervalSeconds: notionAutoSyncIntervalSeconds,
            notionSyncMessage: notionSyncMessage
        )
        guard let data = try? JSONEncoder.pretty.encode(state) else { return }
        try? data.write(to: persistenceURL, options: [.atomic])
    }

    private func apply(_ state: AppState) {
        todos = state.todos.map {
            var todo = $0
            todo.pomodoroMinutes = state.defaultPomodoroMinutes
            todo.breakMinutes = state.defaultBreakMinutes
            return normalized(todo)
        }
        blockedSites = state.blockedSites
        defaultPomodoroMinutes = state.defaultPomodoroMinutes
        defaultBreakMinutes = state.defaultBreakMinutes
        launchAtLogin = state.launchAtLogin
        notificationsEnabled = state.notificationsEnabled
        selectedFocusMusicID = state.selectedFocusMusicID
        todoWidgetPosition = state.todoWidgetPosition
        isTodoWidgetPositionLocked = state.isTodoWidgetPositionLocked
        isTodoWidgetDesktopModeEnabled = state.isTodoWidgetDesktopModeEnabled
        notionEnabled = state.notionEnabled
        notionDatabaseID = state.notionDatabaseID
        notionLastSyncedAt = state.notionLastSyncedAt
        notionAutoSyncEnabled = state.notionAutoSyncEnabled
        notionAutoSyncIntervalSeconds = state.notionAutoSyncIntervalSeconds
        notionSyncMessage = state.notionSyncMessage.isEmpty
            ? state.notionLastSyncedAt.map { "마지막 동기화 \(Formatters.relativeTime($0))" } ?? ""
            : state.notionSyncMessage
        selectedTodoID = todos.first?.id
    }

    private func needsTimerMigration(_ state: AppState) -> Bool {
        state.todos.contains {
            $0.pomodoroMinutes != state.defaultPomodoroMinutes ||
            $0.breakMinutes != state.defaultBreakMinutes
        }
    }

    private func mergeNotionTodos(_ notionTodos: [TodoItem]) {
        let remotePageIDs = Set(notionTodos.compactMap(\.notionPageID))
        var mergedTodos = todos.filter { todo in
            guard let pageID = todo.notionPageID else { return true }
            return remotePageIDs.contains(pageID)
        }

        for remoteTodo in notionTodos {
            guard let pageID = remoteTodo.notionPageID else { continue }

            if let index = mergedTodos.firstIndex(where: { $0.notionPageID == pageID }) {
                var updated = remoteTodo
                updated.id = mergedTodos[index].id
                updated.completedPomodoros = mergedTodos[index].completedPomodoros
                updated.pomodoroMinutes = mergedTodos[index].pomodoroMinutes
                updated.breakMinutes = mergedTodos[index].breakMinutes
                mergedTodos[index] = updated
            } else {
                mergedTodos.append(remoteTodo)
            }
        }

        todos = mergedTodos.sorted {
            if $0.notionPageID != nil, $1.notionPageID == nil { return true }
            if $0.notionPageID == nil, $1.notionPageID != nil { return false }
            return $0.todoDate > $1.todoDate
        }

        if let selectedTodoID, !todos.contains(where: { $0.id == selectedTodoID }) {
            self.selectedTodoID = todos.first?.id
        } else if selectedTodoID == nil {
            selectedTodoID = todos.first?.id
        }
    }

    private var canSyncNotion: Bool {
        notionEnabled &&
            !notionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !notionDatabaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalized(_ todo: TodoItem) -> TodoItem {
        var normalized = todo
        if normalized.isDone {
            normalized.status = .completed
        } else if normalized.status == .completed {
            normalized.status = .notStarted
        }
        return normalized
    }

    private func scheduleNotionUpsert(
        _ todo: TodoItem,
        delayNanoseconds: UInt64 = 850_000_000
    ) {
        guard canSyncNotion else { return }

        notionSyncTasks[todo.id]?.cancel()
        notionSyncTasks[todo.id] = Task { @MainActor [weak self] in
            if delayNanoseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: delayNanoseconds)
                } catch {
                    return
                }
            }

            await self?.upsertNotionTodo(todo)
        }
    }

    private func upsertNotionTodo(_ todo: TodoItem) async {
        guard canSyncNotion else { return }

        do {
            let syncedTodo = try await notionClient.upsertTodo(
                todo,
                token: notionToken,
                databaseOrDataSourceID: notionDatabaseID
            )

            if let index = todos.firstIndex(where: { $0.id == syncedTodo.id }) {
                todos[index].notionPageID = syncedTodo.notionPageID
                todos[index].notionURL = syncedTodo.notionURL
                notionLastSyncedAt = Date()
                notionSyncMessage = "노션에 업데이트했습니다."
                save()
            }
        } catch {
            notionSyncMessage = error.localizedDescription
        }
    }

    private func archiveNotionTodo(pageID: String) {
        guard canSyncNotion else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await notionClient.archiveTodo(pageID: pageID, token: notionToken)
                notionLastSyncedAt = Date()
                notionSyncMessage = "노션 항목을 보관했습니다."
                save()
            } catch {
                notionSyncMessage = error.localizedDescription
            }
        }
    }
}
