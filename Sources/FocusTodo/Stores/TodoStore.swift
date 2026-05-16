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

    private let persistenceURL: URL

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
    }

    var selectedTodo: TodoItem? {
        guard let selectedTodoID else { return todos.first }
        return todos.first { $0.id == selectedTodoID } ?? todos.first
    }

    func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        insertNewTodo(title: title)
        newTodoTitle = ""
    }

    @discardableResult
    func addQuickMemoTodo() -> TodoItem {
        insertNewTodo(title: nextQuickMemoTodoTitle())
    }

    @discardableResult
    private func insertNewTodo(title: String) -> TodoItem {
        let todo = TodoItem(
            title: title,
            pomodoroMinutes: defaultPomodoroMinutes,
            breakMinutes: defaultBreakMinutes
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
        todos.removeAll { $0.id == todo.id }
        if selectedTodoID == todo.id {
            selectedTodoID = todos.first?.id
        }
        save()
    }

    func updateTodo(_ todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == todo.id }) else { return }
        todos[index] = todo
        save()
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
            isTodoWidgetPositionLocked: isTodoWidgetPositionLocked
        )
        guard let data = try? JSONEncoder.pretty.encode(state) else { return }
        try? data.write(to: persistenceURL, options: [.atomic])
    }

    private func apply(_ state: AppState) {
        todos = state.todos.map {
            var todo = $0
            todo.pomodoroMinutes = state.defaultPomodoroMinutes
            todo.breakMinutes = state.defaultBreakMinutes
            return todo
        }
        blockedSites = state.blockedSites
        defaultPomodoroMinutes = state.defaultPomodoroMinutes
        defaultBreakMinutes = state.defaultBreakMinutes
        launchAtLogin = state.launchAtLogin
        notificationsEnabled = state.notificationsEnabled
        selectedFocusMusicID = state.selectedFocusMusicID
        todoWidgetPosition = state.todoWidgetPosition
        isTodoWidgetPositionLocked = state.isTodoWidgetPositionLocked
        selectedTodoID = todos.first?.id
    }

    private func needsTimerMigration(_ state: AppState) -> Bool {
        state.todos.contains {
            $0.pomodoroMinutes != state.defaultPomodoroMinutes ||
            $0.breakMinutes != state.defaultBreakMinutes
        }
    }
}
