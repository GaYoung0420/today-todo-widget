import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: TodoStore
    let session: PomodoroSession
    let showPomodoro: (TodoItem) -> Void
    let showMemo: (TodoItem) -> Void
    let createTodoAndShowMemo: () -> Void
    let setTodoWidgetLocked: (Bool) -> Void
    let showSettings: (Bool) -> Void

    @State private var isAddingTodo = false
    @State private var hoveredTodoID: TodoItem.ID?
    @State private var editingTodoID: TodoItem.ID?
    @State private var editingTodoTitle = ""
    @State private var draggedTodoID: TodoItem.ID?
    @State private var dropTargetTodoID: TodoItem.ID?
    @State private var dropPlacement: TodoDropPlacement?
    @State private var viewMode: TodoWidgetViewMode = .list

    var body: some View {
        HStack(spacing: 0) {
            todoWidget
            todoWidgetHandle
        }
        .frame(
            minWidth: TodoWidgetLayout.windowWidth,
            maxWidth: .infinity,
            minHeight: TodoWidgetLayout.windowHeight,
            maxHeight: .infinity
        )
    }

    private var todoWidget: some View {
        VStack(spacing: 0) {
            header
            DateNavigator(store: store, compact: true)
            NotionSyncStrip(store: store, compact: true)
            TodoWidgetViewModePicker(selection: $viewMode)
            if viewMode == .list {
                todoList
            } else {
                timeTracker
            }
            footer
        }
        .frame(
            minWidth: TodoWidgetLayout.contentWidth,
            maxWidth: .infinity,
            minHeight: TodoWidgetLayout.contentHeight,
            maxHeight: .infinity
        )
        .floatingWidgetSurface(TodoWidgetLayout.shape)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.primary)

            Text("할 일")
                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.charcoal)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(store.completedTodosForSelectedDateCount)/\(store.todosForSelectedDate.count)")
                .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.stone)
                .monospacedDigit()

            Button {
                setTodoWidgetLocked(!store.isTodoWidgetPositionLocked)
            } label: {
                Image(systemName: store.isTodoWidgetPositionLocked ? "lock.fill" : "lock.open.fill")
            }
            .buttonStyle(DesignIconButtonStyle(
                tint: store.isTodoWidgetPositionLocked ? NotionDesign.Colors.primary : NotionDesign.Colors.steel,
                size: 22,
                background: store.isTodoWidgetPositionLocked ? NotionDesign.Colors.primaryLight : .clear
            ))
            .help(store.isTodoWidgetPositionLocked ? "위치 잠금 해제" : "위치 잠금")

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    viewMode = .list
                    isAddingTodo = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.stone, size: 22, background: .clear))
            .help("투두 추가")

            Button {
                showSettings(false)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.steel, size: 22))
            .help("설정")

            Button {
                NSApp.hide(nil)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.steel, size: 22))
            .help("숨기기")
        }
        .padding(.horizontal, NotionDesign.Panel.headerHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: NotionDesign.Panel.headerHeight)
        .background(NotionDesign.Colors.canvas.opacity(0.62))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }

    private var todoList: some View {
        AlwaysVisibleVerticalScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.todosForSelectedDate) { todo in
                    TodoRow(
                        todo: todo,
                        isHovered: hoveredTodoID == todo.id,
                        isSelected: store.selectedTodoID == todo.id,
                        isActive: session.activeTodo?.id == todo.id,
                        activeRemainingSeconds: session.activeTodo?.id == todo.id ? session.remainingSeconds : nil,
                        isEditing: editingTodoID == todo.id,
                        editingTitle: $editingTodoTitle,
                        beginEditing: { beginEditing(todo) },
                        commitEditing: { commitEditing(todo.id) },
                        cancelEditing: cancelEditing,
                        start: { showPomodoro(todo) },
                        memo: { showMemo(todo) },
                        toggleDone: { toggleDone(todo) },
                        delete: { store.deleteTodo(todo) },
                        dropPlacement: dropTargetTodoID == todo.id ? dropPlacement : nil,
                        beginDrag: {
                            beginDragging(todo)
                        },
                        endDrag: {
                            if draggedTodoID == todo.id {
                                draggedTodoID = nil
                                dropTargetTodoID = nil
                                dropPlacement = nil
                            }
                        }
                    )
                    .onDrop(
                        of: [.text],
                        delegate: TodoDropDelegate(
                            targetTodo: todo,
                            draggedTodoID: $draggedTodoID,
                            dropTargetTodoID: $dropTargetTodoID,
                            dropPlacement: $dropPlacement,
                            store: store
                        )
                    )
                    .onHover { hovering in
                        hoveredTodoID = hovering ? todo.id : nil
                    }
                }

                if store.todosForSelectedDate.isEmpty && !isAddingTodo {
                    EmptyDateTodoHint()
                }

                Color.clear
                    .frame(height: 14)
                    .overlay(alignment: .bottom) {
                        if dropPlacement == .end {
                            DropIndicator()
                        }
                    }
                    .onDrop(
                        of: [.text],
                        delegate: TodoListEndDropDelegate(
                            draggedTodoID: $draggedTodoID,
                            dropTargetTodoID: $dropTargetTodoID,
                            dropPlacement: $dropPlacement,
                            store: store
                        )
                    )

                if isAddingTodo {
                    AddTodoInlineRow(
                        title: $store.newTodoTitle,
                        commit: commitAddTodo,
                        cancel: {
                            store.newTodoTitle = ""
                            isAddingTodo = false
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 152, maxHeight: .infinity)
        .clipped()
    }

    private var timeTracker: some View {
        TimeTrackerView(
            todos: store.todosForSelectedDate,
            selectedDate: store.selectedDate,
            activeTodoID: session.activeTodo?.id,
            selectedTodoID: store.selectedTodoID,
            select: { todo in
                store.selectedTodoID = todo.id
            },
            toggleDone: { todo in
                store.toggleDone(todo)
            },
            memo: showMemo
        )
        .frame(minHeight: 152, maxHeight: .infinity)
        .clipped()
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                createTodoAndShowMemo()
            } label: {
                HStack(spacing: 5) {
                    ShortcutBadge("⌘M")
                    Text("새 메모")
                }
            }
            .buttonStyle(FooterLinkButtonStyle())
            .help("새 투두 메모")

            Spacer()

            Button {
                showSettings(true)
            } label: {
                HStack(spacing: 5) {
                    ShortcutBadge("⌘⇧B")
                    Text("차단")
                }
            }
            .buttonStyle(FooterLinkButtonStyle())
            .help("차단 사이트 관리")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(NotionDesign.Colors.canvas.opacity(0.64))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }

    private func commitAddTodo() {
        store.addTodo()
        isAddingTodo = false
    }

    private func toggleDone(_ todo: TodoItem) {
        store.toggleDone(todo)
    }

    private func beginEditing(_ todo: TodoItem) {
        if let editingTodoID, editingTodoID != todo.id {
            commitEditing(editingTodoID)
        }

        store.selectedTodoID = todo.id
        editingTodoID = todo.id
        editingTodoTitle = todo.title
    }

    private func commitEditing(_ todoID: TodoItem.ID) {
        guard editingTodoID == todoID else { return }
        defer { cancelEditing() }

        let title = editingTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, var updated = store.todos.first(where: { $0.id == todoID }) else { return }

        updated.title = title
        store.updateTodo(updated)
    }

    private func cancelEditing() {
        editingTodoID = nil
        editingTodoTitle = ""
    }

    private func beginDragging(_ todo: TodoItem) {
        draggedTodoID = todo.id
        dropTargetTodoID = nil
        dropPlacement = nil
        let dragID = todo.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if draggedTodoID == dragID {
                draggedTodoID = nil
                dropTargetTodoID = nil
                dropPlacement = nil
            }
        }
    }

    private var todoWidgetHandle: some View {
        ZStack {
            Capsule()
                .fill(NotionDesign.Colors.surface.opacity(store.isTodoWidgetPositionLocked ? 0.42 : 0.92))
                .frame(width: 8, height: 62)
                .overlay {
                    Capsule()
                        .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
                }

            VStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(store.isTodoWidgetPositionLocked ? NotionDesign.Colors.muted : NotionDesign.Colors.steel)
                        .frame(width: 3, height: 12)
                }
            }

            WindowDragArea(
                isLocked: store.isTodoWidgetPositionLocked,
                onMoved: { origin in
                    store.setTodoWidgetPosition(x: origin.x, y: origin.y)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                WindowResizeArea()
                    .frame(width: TodoWidgetLayout.handleWidth, height: 34)
            }
        }
        .frame(width: TodoWidgetLayout.handleWidth)
        .frame(minHeight: TodoWidgetLayout.contentHeight, maxHeight: .infinity)
        .contentShape(Rectangle())
        .help(store.isTodoWidgetPositionLocked ? "위치는 잠겨 있고 핸들에서 크기 조절 가능" : "드래그해서 이동하거나 핸들에서 크기 조절")
    }
}

struct MenuTodoPanelView: View {
    @Bindable var store: TodoStore
    let session: PomodoroSession
    let showPomodoro: (TodoItem) -> Void
    let showMemo: (TodoItem) -> Void
    let createTodoAndShowMemo: () -> Void
    let showSettings: (Bool) -> Void
    let close: () -> Void

    @State private var isAddingTodo = false
    @State private var hoveredTodoID: TodoItem.ID?
    @State private var editingTodoID: TodoItem.ID?
    @State private var editingTodoTitle = ""
    @State private var draggedTodoID: TodoItem.ID?
    @State private var dropTargetTodoID: TodoItem.ID?
    @State private var dropPlacement: TodoDropPlacement?
    @State private var viewMode: TodoWidgetViewMode = .list

    var body: some View {
        VStack(spacing: 0) {
            header
            DateNavigator(store: store, compact: false)
            NotionSyncStrip(store: store, compact: false)
            TodoWidgetViewModePicker(selection: $viewMode)
            if viewMode == .list {
                todoList
            } else {
                timeTracker
            }
            footer
        }
        .frame(
            minWidth: MenuTodoPanelLayout.contentWidth,
            maxWidth: .infinity,
            minHeight: MenuTodoPanelLayout.minimumContentHeight,
            maxHeight: .infinity
        )
        .floatingWidgetSurface(MenuTodoPanelLayout.shape)
        .frame(
            minWidth: MenuTodoPanelLayout.windowWidth,
            maxWidth: .infinity,
            minHeight: MenuTodoPanelLayout.minimumWindowHeight,
            maxHeight: .infinity
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.primary)

            Text("할 일")
                .font(NotionDesign.Fonts.pretendard(size: 15, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.charcoal)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(store.completedTodosForSelectedDateCount)/\(store.todosForSelectedDate.count)")
                .font(NotionDesign.Fonts.pretendard(size: 12, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.stone)
                .monospacedDigit()

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    viewMode = .list
                    isAddingTodo = true
                }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.stone, size: 24, background: .clear))
            .help("투두 추가")

            Button {
                showSettings(false)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.steel, size: 24))
            .help("설정")

            Button(action: close) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.steel, size: 24))
            .help("닫기")
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: MenuTodoPanelLayout.headerHeight)
        .background(NotionDesign.Colors.canvas.opacity(0.9))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }

    private var todoList: some View {
        AlwaysVisibleVerticalScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.todosForSelectedDate) { todo in
                    TodoRow(
                        todo: todo,
                        isHovered: hoveredTodoID == todo.id,
                        isSelected: store.selectedTodoID == todo.id,
                        isActive: session.activeTodo?.id == todo.id,
                        activeRemainingSeconds: session.activeTodo?.id == todo.id ? session.remainingSeconds : nil,
                        isEditing: editingTodoID == todo.id,
                        editingTitle: $editingTodoTitle,
                        beginEditing: { beginEditing(todo) },
                        commitEditing: { commitEditing(todo.id) },
                        cancelEditing: cancelEditing,
                        start: { showPomodoro(todo) },
                        memo: { showMemo(todo) },
                        toggleDone: { toggleDone(todo) },
                        delete: { store.deleteTodo(todo) },
                        dropPlacement: dropTargetTodoID == todo.id ? dropPlacement : nil,
                        beginDrag: { beginDragging(todo) },
                        endDrag: {
                            if draggedTodoID == todo.id {
                                draggedTodoID = nil
                                dropTargetTodoID = nil
                                dropPlacement = nil
                            }
                        }
                    )
                    .onDrop(
                        of: [.text],
                        delegate: TodoDropDelegate(
                            targetTodo: todo,
                            draggedTodoID: $draggedTodoID,
                            dropTargetTodoID: $dropTargetTodoID,
                            dropPlacement: $dropPlacement,
                            store: store
                        )
                    )
                    .onHover { hovering in
                        hoveredTodoID = hovering ? todo.id : nil
                    }
                }

                if store.todosForSelectedDate.isEmpty && !isAddingTodo {
                    EmptyDateTodoHint()
                }

                Color.clear
                    .frame(height: 14)
                    .overlay(alignment: .bottom) {
                        if dropPlacement == .end {
                            DropIndicator()
                        }
                    }
                    .onDrop(
                        of: [.text],
                        delegate: TodoListEndDropDelegate(
                            draggedTodoID: $draggedTodoID,
                            dropTargetTodoID: $dropTargetTodoID,
                            dropPlacement: $dropPlacement,
                            store: store
                        )
                    )

                if isAddingTodo {
                    AddTodoInlineRow(
                        title: $store.newTodoTitle,
                        commit: commitAddTodo,
                        cancel: {
                            store.newTodoTitle = ""
                            isAddingTodo = false
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 8)
        }
        .frame(minHeight: 300, maxHeight: .infinity)
        .clipped()
    }

    private var timeTracker: some View {
        TimeTrackerView(
            todos: store.todosForSelectedDate,
            selectedDate: store.selectedDate,
            activeTodoID: session.activeTodo?.id,
            selectedTodoID: store.selectedTodoID,
            select: { todo in
                store.selectedTodoID = todo.id
            },
            toggleDone: { todo in
                store.toggleDone(todo)
            },
            memo: showMemo
        )
        .frame(minHeight: 300, maxHeight: .infinity)
        .clipped()
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                createTodoAndShowMemo()
            } label: {
                HStack(spacing: 5) {
                    ShortcutBadge("⌘M")
                    Text("새 메모")
                }
            }
            .buttonStyle(FooterLinkButtonStyle())
            .help("새 투두 메모")

            Spacer()

            Button {
                showSettings(true)
            } label: {
                HStack(spacing: 5) {
                    ShortcutBadge("⌘⇧B")
                    Text("차단")
                }
            }
            .buttonStyle(FooterLinkButtonStyle())
            .help("차단 사이트 관리")
        }
        .padding(.horizontal, 16)
        .frame(height: MenuTodoPanelLayout.footerHeight)
        .background(NotionDesign.Colors.canvas.opacity(0.9))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }

    private func commitAddTodo() {
        store.addTodo()
        isAddingTodo = false
    }

    private func toggleDone(_ todo: TodoItem) {
        store.toggleDone(todo)
    }

    private func beginEditing(_ todo: TodoItem) {
        if let editingTodoID, editingTodoID != todo.id {
            commitEditing(editingTodoID)
        }

        store.selectedTodoID = todo.id
        editingTodoID = todo.id
        editingTodoTitle = todo.title
    }

    private func commitEditing(_ todoID: TodoItem.ID) {
        guard editingTodoID == todoID else { return }
        defer { cancelEditing() }

        let title = editingTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, var updated = store.todos.first(where: { $0.id == todoID }) else { return }

        updated.title = title
        store.updateTodo(updated)
    }

    private func cancelEditing() {
        editingTodoID = nil
        editingTodoTitle = ""
    }

    private func beginDragging(_ todo: TodoItem) {
        draggedTodoID = todo.id
        dropTargetTodoID = nil
        dropPlacement = nil
        let dragID = todo.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if draggedTodoID == dragID {
                draggedTodoID = nil
                dropTargetTodoID = nil
                dropPlacement = nil
            }
        }
    }
}

enum TodoWidgetLayout {
    static let contentWidth: CGFloat = 340
    static let contentHeight: CGFloat = 338
    static let rowHeight: CGFloat = 38
    static let viewModeHeight: CGFloat = 30
    static let handleWidth: CGFloat = 18
    static let resizeEdgeThickness: CGFloat = 6
    static let resizeCornerSize: CGFloat = 24
    static let shadowPadding = NotionDesign.Panel.shadowPadding
    static let windowWidth = contentWidth + handleWidth + shadowPadding * 2
    static let windowHeight = contentHeight + shadowPadding * 2
    static let shape = RoundedRectangle(cornerRadius: NotionDesign.Radius.widget, style: .continuous)
}

enum MenuTodoPanelLayout {
    static let contentWidth: CGFloat = 440
    static let contentHeight: CGFloat = 520
    static let minimumContentHeight: CGFloat = 360
    static let minimumWindowHeight: CGFloat = 360
    static let headerHeight: CGFloat = 58
    static let footerHeight: CGFloat = 46
    static let windowWidth = contentWidth
    static let windowHeight = contentHeight
    static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
}

private enum TodoWidgetViewMode: String, CaseIterable {
    case list
    case timeTracker

    var iconName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .timeTracker:
            return "calendar.day.timeline.left"
        }
    }

    var title: String {
        switch self {
        case .list:
            return "리스트"
        case .timeTracker:
            return "타임"
        }
    }
}

private struct TodoWidgetViewModePicker: View {
    @Binding var selection: TodoWidgetViewMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TodoWidgetViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.title)
                            .font(NotionDesign.Fonts.pretendard(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WidgetModeButtonStyle(isSelected: selection == mode))
                .help(mode == .list ? "리스트 보기" : "타임트래커 보기")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: TodoWidgetLayout.viewModeHeight)
        .background(NotionDesign.Colors.canvas.opacity(0.62))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }
}

private struct WidgetModeButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? NotionDesign.Colors.primary : NotionDesign.Colors.steel)
            .frame(height: 22)
            .background(
                isSelected ? NotionDesign.Colors.primaryLight : NotionDesign.Colors.surfaceSoft,
                in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(isSelected ? NotionDesign.Colors.primary.opacity(0.18) : NotionDesign.Colors.hairlineSoft, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

private struct DateNavigator: View {
    @Bindable var store: TodoStore
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Button {
                store.moveSelectedDate(byDays: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(DateNavIconButtonStyle())
            .help("이전 날짜")

            Button {
                store.selectToday()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .semibold))
                    Text(Formatters.todoDateTitle(store.selectedDate))
                        .font(NotionDesign.Fonts.pretendard(size: compact ? 12 : 13, weight: .semibold))
                        .monospacedDigit()
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DateNavTitleButtonStyle(isToday: Calendar.current.isDateInToday(store.selectedDate)))
            .help("\(Formatters.todoDateAccessibility(store.selectedDate)), 오늘로 이동")

            Button {
                store.moveSelectedDate(byDays: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(DateNavIconButtonStyle())
            .help("다음 날짜")
        }
        .padding(.horizontal, compact ? 10 : 14)
        .frame(height: compact ? 34 : 38)
        .background(NotionDesign.Colors.surfaceSoft)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }
}

private struct NotionSyncStrip: View {
    @Bindable var store: TodoStore
    let compact: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(store.notionWidgetSyncText)
                .font(NotionDesign.Fonts.pretendard(size: compact ? 10 : 11, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.steel)
                .lineLimit(1)

            if store.notionAutoSyncEnabled, store.notionEnabled {
                Text("\(store.notionAutoSyncIntervalSeconds)초")
                    .font(NotionDesign.Fonts.pretendard(size: 10, weight: .semibold))
                    .foregroundStyle(NotionDesign.Colors.stone)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                store.refreshNotionTodosNow()
            } label: {
                if store.isNotionSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.62)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .buttonStyle(SyncRefreshButtonStyle())
            .disabled(!store.canManuallySyncNotion || store.isNotionSyncing)
            .help(syncHelpText)
        }
        .padding(.horizontal, compact ? 12 : 16)
        .frame(height: compact ? 28 : 30)
        .background(NotionDesign.Colors.canvas.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }

    private var statusColor: Color {
        if store.isNotionSyncing {
            return NotionDesign.Colors.primary
        }
        if !store.notionEnabled {
            return NotionDesign.Colors.muted
        }
        if store.notionWidgetSyncText.contains("필요") ||
            store.notionWidgetSyncText.contains("실패") ||
            store.notionSyncMessage.contains("오류") ||
            store.notionSyncMessage.contains("unauthorized") ||
            store.notionSyncMessage.contains("invalid") {
            return NotionDesign.Colors.error
        }
        return NotionDesign.Colors.success
    }

    private var syncHelpText: String {
        if !store.notionEnabled {
            return "노션 연동이 꺼져 있습니다"
        }
        if store.notionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            store.notionDatabaseID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "토큰과 DB URL/ID를 입력해주세요"
        }
        return "노션에서 지금 업데이트"
    }
}

private struct SyncRefreshButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(NotionDesign.Colors.steel)
            .frame(width: 22, height: 20)
            .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct EmptyDateTodoHint: View {
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.stone)

            Text("이 날짜에 할 일이 없습니다")
                .font(NotionDesign.Fonts.pretendard(size: 12, weight: .regular))
                .foregroundStyle(NotionDesign.Colors.steel)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}

private struct TimeTrackerView: View {
    let todos: [TodoItem]
    let selectedDate: Date
    let activeTodoID: TodoItem.ID?
    let selectedTodoID: TodoItem.ID?
    let select: (TodoItem) -> Void
    let toggleDone: (TodoItem) -> Void
    let memo: (TodoItem) -> Void

    private var scheduledTodos: [TodoItem] {
        todos
            .filter { $0.scheduledStartAt != nil }
            .sorted {
                ($0.scheduledStartAt ?? $0.todoDate) < ($1.scheduledStartAt ?? $1.todoDate)
            }
    }

    var body: some View {
        AlwaysVisibleVerticalScrollView(
            scrollToY: initialScrollY,
            scrollRequestID: scrollRequestID
        ) {
            TimeTrackerDayGrid(
                todos: scheduledTodos,
                selectedDate: selectedDate,
                activeTodoID: activeTodoID,
                selectedTodoID: selectedTodoID,
                select: select,
                toggleDone: toggleDone,
                memo: memo
            )
        }
        .background(NotionDesign.Colors.surfaceSoft.opacity(0.46))
    }

    private var initialScrollY: CGFloat? {
        guard Calendar.current.isDateInToday(selectedDate) else { return nil }
        return max(currentTimeY(Date()) - TimeTrackerLayout.initialCurrentTimeOffset, 0)
    }

    private var scrollRequestID: String {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        return "time-tracker-\(Int(startOfDay))-\(Calendar.current.isDateInToday(selectedDate))"
    }

    private func currentTimeY(_ date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = min(max((components.hour ?? 0) * 60 + (components.minute ?? 0), 0), 24 * 60)
        return TimeTrackerLayout.topPadding + CGFloat(minutes) / 60 * TimeTrackerLayout.hourHeight
    }
}

private struct TimeTrackerDayGrid: View {
    let todos: [TodoItem]
    let selectedDate: Date
    let activeTodoID: TodoItem.ID?
    let selectedTodoID: TodoItem.ID?
    let select: (TodoItem) -> Void
    let toggleDone: (TodoItem) -> Void
    let memo: (TodoItem) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(0...24, id: \.self) { hour in
                    TimeTrackerHourLine(hour: hour)
                        .frame(width: proxy.size.width)
                        .position(
                            x: proxy.size.width / 2,
                            y: TimeTrackerLayout.topPadding + CGFloat(hour) * TimeTrackerLayout.hourHeight
                        )
                }

                if Calendar.current.isDateInToday(selectedDate) {
                    TimelineView(.periodic(from: Date(), by: 60)) { context in
                        CurrentTimeLine()
                            .frame(width: proxy.size.width - TimeTrackerLayout.labelWidth - 10)
                            .position(
                                x: TimeTrackerLayout.labelWidth + (proxy.size.width - TimeTrackerLayout.labelWidth - 10) / 2,
                                y: currentTimeY(context.date)
                            )
                            .zIndex(10)
                    }
                }

                ForEach(eventPlacements(for: todos)) { placement in
                    TimeTrackerEventBlock(
                        todo: placement.todo,
                        isActive: activeTodoID == placement.todo.id,
                        isSelected: selectedTodoID == placement.todo.id,
                        isCompact: placement.isCompact || placement.columnCount > 1,
                        toggleDone: { toggleDone(placement.todo) }
                    )
                    .frame(
                        width: eventWidth(containerWidth: proxy.size.width, columnCount: placement.columnCount),
                        height: placement.visualHeight
                    )
                    .position(
                        x: eventX(containerWidth: proxy.size.width, column: placement.column, columnCount: placement.columnCount),
                        y: TimeTrackerLayout.topPadding + placement.visualTop + placement.visualHeight / 2
                    )
                    .onTapGesture {
                        select(placement.todo)
                    }
                    .onTapGesture(count: 2) {
                        memo(placement.todo)
                    }
                }

                if todos.isEmpty {
                    HStack(spacing: 7) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NotionDesign.Colors.stone)
                        Text("시간이 있는 노션 할 일이 없습니다")
                            .font(NotionDesign.Fonts.pretendard(size: 12, weight: .regular))
                            .foregroundStyle(NotionDesign.Colors.steel)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .position(x: proxy.size.width / 2, y: TimeTrackerLayout.topPadding + 25)
                }
            }
        }
        .frame(height: TimeTrackerLayout.totalHeight)
    }

    private func eventY(for todo: TodoItem) -> CGFloat {
        CGFloat(startMinute(for: todo)) / 60 * TimeTrackerLayout.hourHeight
    }

    private func currentTimeY(_ date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = min(max((components.hour ?? 0) * 60 + (components.minute ?? 0), 0), 24 * 60)
        return TimeTrackerLayout.topPadding + CGFloat(minutes) / 60 * TimeTrackerLayout.hourHeight
    }

    private func eventHeight(for todo: TodoItem) -> CGFloat {
        let durationMinutes = durationMinutes(for: todo)
        guard durationMinutes > 0 else { return TimeTrackerLayout.markerHeight }
        let naturalHeight = CGFloat(durationMinutes) / 60 * TimeTrackerLayout.hourHeight
        if durationMinutes <= TimeTrackerLayout.compactDurationMinutes {
            return max(naturalHeight, TimeTrackerLayout.minimumCompactEventHeight)
        }
        return max(naturalHeight, TimeTrackerLayout.minimumEventHeight)
    }

    private func startMinute(for todo: TodoItem) -> Int {
        minuteOfDay(todo.scheduledStartAt ?? todo.todoDate)
    }

    private func endMinute(for todo: TodoItem) -> Int {
        guard let end = todo.scheduledEndAt else { return startMinute(for: todo) }
        let endMinute = minuteOfDay(end)
        if endMinute == 0, !Calendar.current.isDate(end, inSameDayAs: todo.scheduledStartAt ?? todo.todoDate) {
            return 24 * 60
        }
        return max(endMinute, startMinute(for: todo))
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return min(max((components.hour ?? 0) * 60 + (components.minute ?? 0), 0), 24 * 60)
    }

    private func durationMinutes(for todo: TodoItem) -> Int {
        max(endMinute(for: todo) - startMinute(for: todo), 0)
    }

    private func eventPlacements(for todos: [TodoItem]) -> [TimeTrackerEventPlacement] {
        let placements = todos.map { todo in
            TimeTrackerEventPlacement(
                todo: todo,
                actualStartMinute: startMinute(for: todo),
                actualEndMinute: endMinute(for: todo),
                visualTop: eventY(for: todo),
                visualHeight: eventHeight(for: todo),
                isCompact: durationMinutes(for: todo) <= TimeTrackerLayout.compactDurationMinutes
            )
        }
        .sorted {
            if $0.actualStartMinute == $1.actualStartMinute {
                return $0.actualEndMinute > $1.actualEndMinute
            }
            return $0.actualStartMinute < $1.actualStartMinute
        }

        var result: [TimeTrackerEventPlacement] = []
        var group: [TimeTrackerEventPlacement] = []
        var groupEndMinute = 0

        for placement in placements {
            if group.isEmpty {
                group = [placement]
                groupEndMinute = placement.actualEndMinute
            } else if placement.actualStartMinute < groupEndMinute {
                group.append(placement)
                groupEndMinute = max(groupEndMinute, placement.actualEndMinute)
            } else {
                result.append(contentsOf: columnizedPlacements(group))
                group = [placement]
                groupEndMinute = placement.actualEndMinute
            }
        }

        if !group.isEmpty {
            result.append(contentsOf: columnizedPlacements(group))
        }

        return result
    }

    private func columnizedPlacements(_ group: [TimeTrackerEventPlacement]) -> [TimeTrackerEventPlacement] {
        var columnEndMinutes: [Int] = []
        var placed: [TimeTrackerEventPlacement] = []

        for placement in group {
            let reusableColumn = columnEndMinutes.firstIndex {
                placement.actualStartMinute >= $0
            }
            let column = reusableColumn ?? columnEndMinutes.count

            if reusableColumn == nil {
                columnEndMinutes.append(placement.actualEndMinute)
            } else {
                columnEndMinutes[column] = placement.actualEndMinute
            }

            var updated = placement
            updated.column = column
            placed.append(updated)
        }

        let columnCount = max(columnEndMinutes.count, 1)
        return placed.map { placement in
            var updated = placement
            updated.columnCount = columnCount
            return updated
        }
    }

    private func eventWidth(containerWidth: CGFloat, columnCount: Int) -> CGFloat {
        let availableWidth = max(containerWidth - TimeTrackerLayout.labelWidth - 18, 120)
        let totalGap = CGFloat(max(columnCount - 1, 0)) * TimeTrackerLayout.eventGap
        return max((availableWidth - totalGap) / CGFloat(max(columnCount, 1)), 58)
    }

    private func eventX(containerWidth: CGFloat, column: Int, columnCount: Int) -> CGFloat {
        let width = eventWidth(containerWidth: containerWidth, columnCount: columnCount)
        return TimeTrackerLayout.labelWidth + 8 + width / 2 + CGFloat(column) * (width + TimeTrackerLayout.eventGap)
    }
}

private struct TimeTrackerEventPlacement: Identifiable {
    let todo: TodoItem
    let actualStartMinute: Int
    let actualEndMinute: Int
    let visualTop: CGFloat
    let visualHeight: CGFloat
    let isCompact: Bool
    var column = 0
    var columnCount = 1

    var id: TodoItem.ID { todo.id }
}

private struct TimeTrackerHourLine: View {
    let hour: Int

    var body: some View {
        HStack(spacing: 0) {
            Text(String(format: "%02d시", hour))
                .font(NotionDesign.Fonts.pretendard(size: 11, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.steel)
                .monospacedDigit()
                .frame(width: TimeTrackerLayout.labelWidth - 8, alignment: .trailing)
                .padding(.trailing, 8)

            Rectangle()
                .fill(NotionDesign.Colors.hairlineSoft)
                .frame(height: 1)
        }
    }
}

private struct CurrentTimeLine: View {
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(NotionDesign.Colors.error)
                .frame(width: 6, height: 6)

            Rectangle()
                .fill(NotionDesign.Colors.error.opacity(0.72))
                .frame(height: 1.5)
        }
        .shadow(color: NotionDesign.Colors.error.opacity(0.16), radius: 3, x: 0, y: 1)
        .accessibilityLabel("현재 시간")
    }
}

private struct TimeTrackerEventBlock: View {
    let todo: TodoItem
    let isActive: Bool
    let isSelected: Bool
    let isCompact: Bool
    let toggleDone: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(alignment: isCompact ? .center : .top, spacing: isCompact ? 4 : 6) {
                CheckCircle(
                    checked: todo.isDone,
                    tint: isActive ? NotionDesign.Colors.primary : NotionDesign.Colors.stone,
                    size: isCompact ? 10 : 15
                )
                .frame(width: isCompact ? 11 : 16, height: isCompact ? 11 : 16)
                .padding(.top, isCompact ? 0 : 1)

                if isCompact {
                    HStack(spacing: 3) {
                        titleText

                        if let scheduledStartAt = todo.scheduledStartAt {
                            Text(Formatters.clockTime(scheduledStartAt))
                                .font(NotionDesign.Fonts.pretendard(size: 9, weight: .regular))
                                .foregroundStyle(NotionDesign.Colors.stone)
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        titleText

                        if let scheduledStartAt = todo.scheduledStartAt {
                            Text(Formatters.todoTimeRange(start: scheduledStartAt, end: todo.scheduledEndAt))
                                .font(NotionDesign.Fonts.pretendard(size: 11, weight: .regular))
                                .foregroundStyle(NotionDesign.Colors.stone)
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            ClickCaptureView(action: toggleDone)
                .frame(width: isCompact ? 32 : 38, height: isCompact ? 22 : 34)
                .offset(x: isCompact ? 0 : 1, y: isCompact ? -4 : 2)
                .contentShape(Rectangle())
                .help(todo.isDone ? "완료 취소" : "완료")
        }
        .padding(.horizontal, isCompact ? 6 : 9)
        .padding(.vertical, isCompact ? 1 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(eventBackground, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: NotionDesign.Radius.medium)
                .stroke(eventStroke, lineWidth: isSelected || isActive ? 1 : 0)
        }
    }

    private var titleText: some View {
        Text(todo.title)
            .font(NotionDesign.Fonts.pretendard(size: isCompact ? 10 : 12, weight: .medium))
            .foregroundStyle(todo.isDone ? NotionDesign.Colors.stone : NotionDesign.Colors.charcoal)
            .strikethrough(todo.isDone, color: NotionDesign.Colors.stone)
            .lineLimit(1)
    }

    private var eventBackground: Color {
        if isActive { return NotionDesign.Colors.primaryLight.opacity(0.82) }
        if isSelected { return NotionDesign.Colors.surface.opacity(0.96) }
        return Color(hex: 0xF5EFEF).opacity(0.78)
    }

    private var eventStroke: Color {
        isActive ? NotionDesign.Colors.primary.opacity(0.24) : NotionDesign.Colors.hairline
    }
}

private enum TimeTrackerLayout {
    static let labelWidth: CGFloat = 58
    static let hourHeight: CGFloat = 58
    static let topPadding: CGFloat = 14
    static let bottomPadding: CGFloat = 18
    static let markerHeight: CGFloat = 24
    static let minimumCompactEventHeight: CGFloat = 12
    static let compactDurationMinutes = 15
    static let minimumEventHeight: CGFloat = 42
    static let eventGap: CGFloat = 4
    static let initialCurrentTimeOffset: CGFloat = 116
    static let totalHeight: CGFloat = topPadding + hourHeight * 24 + bottomPadding
}

private struct DateNavIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NotionDesign.Colors.steel)
            .frame(width: 26, height: 24)
            .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct DateNavTitleButtonStyle: ButtonStyle {
    let isToday: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isToday ? NotionDesign.Colors.primary : NotionDesign.Colors.charcoal)
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(
                isToday ? NotionDesign.Colors.primaryLight : NotionDesign.Colors.surface,
                in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(isToday ? NotionDesign.Colors.primary.opacity(0.18) : NotionDesign.Colors.hairline, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct AlwaysVisibleVerticalScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    var scrollToY: CGFloat?
    var scrollRequestID: String

    init(
        scrollToY: CGFloat? = nil,
        scrollRequestID: String = "",
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.scrollToY = scrollToY
        self.scrollRequestID = scrollRequestID
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller?.controlSize = .small

        let hostingView = NSHostingView(rootView: AnyView(content))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        scrollView.documentView = hostingView
        context.coordinator.hostingView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)
        ])

        context.coordinator.scrollIfNeeded(
            scrollView,
            targetY: scrollToY,
            requestID: scrollRequestID
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller?.controlSize = .small
        context.coordinator.hostingView?.rootView = AnyView(content)
        context.coordinator.scrollIfNeeded(
            scrollView,
            targetY: scrollToY,
            requestID: scrollRequestID
        )
    }

    final class Coordinator {
        var hostingView: NSHostingView<AnyView>?
        private var lastScrollRequestID: String?

        func scrollIfNeeded(_ scrollView: NSScrollView, targetY: CGFloat?, requestID: String) {
            guard let targetY else { return }
            guard lastScrollRequestID != requestID else { return }

            DispatchQueue.main.async {
                if self.scroll(scrollView, toY: targetY) {
                    self.lastScrollRequestID = requestID
                }
            }
        }

        private func scroll(_ scrollView: NSScrollView, toY targetY: CGFloat) -> Bool {
            guard let documentView = scrollView.documentView else { return false }

            scrollView.layoutSubtreeIfNeeded()
            documentView.layoutSubtreeIfNeeded()

            let documentHeight = max(documentView.bounds.height, documentView.fittingSize.height)
            let visibleHeight = scrollView.contentView.bounds.height
            guard documentHeight > 0, visibleHeight > 0 else { return false }

            let maxY = max(documentHeight - visibleHeight, 0)
            let clampedY = min(max(targetY, 0), maxY)
            let scrollY = documentView.isFlipped ? clampedY : maxY - clampedY

            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            return true
        }
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    let isHovered: Bool
    let isSelected: Bool
    let isActive: Bool
    let activeRemainingSeconds: Int?
    let isEditing: Bool
    @Binding var editingTitle: String
    let beginEditing: () -> Void
    let commitEditing: () -> Void
    let cancelEditing: () -> Void
    let start: () -> Void
    let memo: () -> Void
    let toggleDone: () -> Void
    let delete: () -> Void
    let dropPlacement: TodoDropPlacement?
    let beginDrag: () -> Void
    let endDrag: () -> Void

    @FocusState private var isTitleFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                CheckCircle(checked: todo.isDone, tint: isActive ? NotionDesign.Colors.primary : tagColor)
                    .frame(width: 22, height: 22)
                ClickCaptureView(action: toggleDone)
            }
            .frame(width: 32, height: 34)
            .contentShape(Rectangle())
            .help(todo.isDone ? "완료 취소" : "완료")

            ZStack {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        if isEditing {
                            TextField("", text: $editingTitle)
                                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
                                .foregroundStyle(NotionDesign.Colors.charcoal)
                                .textFieldStyle(.plain)
                                .focused($isTitleFocused)
                                .onSubmit(commitEditing)
                                .onExitCommand(perform: cancelEditing)
                                .onChange(of: isTitleFocused) { _, focused in
                                    if !focused {
                                        commitEditing()
                                    }
                                }
                                .layoutPriority(1)
                        } else {
                            Text(todo.title)
                                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
                                .foregroundStyle(todo.isDone ? NotionDesign.Colors.stone : NotionDesign.Colors.charcoal)
                                .strikethrough(todo.isDone, color: NotionDesign.Colors.stone)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }

                        PomodoroProgressDots(todo: todo)
                            .fixedSize()

                        if todo.notionPageID != nil {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(NotionDesign.Colors.steel)
                                .help("노션에서 가져온 항목")
                        }

                        if let activeTimerLabel {
                            ActiveTodoStatusBadge(text: activeTimerLabel)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 6)
                }
                if !isEditing {
                    TodoTextInteractionView(
                        payload: todo.id.uuidString,
                        singleClick: beginEditing,
                        doubleClick: memo,
                        beginDrag: beginDrag,
                        endDrag: endDrag
                    )
                }
            }
            .contentShape(Rectangle())
            .onChange(of: isEditing) { _, editing in
                if editing {
                    DispatchQueue.main.async {
                        isTitleFocused = true
                    }
                }
            }

            if isHovered {
                Button(action: start) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("시작")
                    }
                }
                .buttonStyle(StartPillButtonStyle())
                .help("뽀모도로 시작")

                Button(action: delete) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.stone, size: 20, background: .clear))
                .help("삭제")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: TodoWidgetLayout.rowHeight)
        .background(rowBackground, in: Rectangle())
        .overlay(alignment: .top) {
            if dropPlacement == .before {
                DropIndicator()
            }
        }
        .overlay(alignment: .bottom) {
            if dropPlacement == .after {
                DropIndicator()
            }
        }
        .contentShape(Rectangle())
    }

    private var rowBackground: Color {
        if isHovered { return NotionDesign.Colors.surface.opacity(0.95) }
        if isSelected { return NotionDesign.Colors.primaryLight.opacity(0.42) }
        return .clear
    }

    private var tagColor: Color {
        todo.completedPomodoros >= todo.targetPomodoros ? NotionDesign.Colors.success : NotionDesign.Colors.primary
    }

    private var activeTimerLabel: String? {
        guard isActive, let activeRemainingSeconds else { return nil }
        return "진행 중 \(Formatters.timeRemaining(activeRemainingSeconds))"
    }
}

private struct ActiveTodoStatusBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(NotionDesign.Colors.primary)
                .frame(width: 4, height: 4)

            Text(text)
                .font(NotionDesign.Fonts.pretendard(size: 10, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.primary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .background(NotionDesign.Colors.primaryLight.opacity(0.84), in: Capsule())
        .overlay {
            Capsule()
                .stroke(NotionDesign.Colors.primary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityLabel(text)
    }
}

private struct TodoDropDelegate: DropDelegate {
    let targetTodo: TodoItem
    @Binding var draggedTodoID: TodoItem.ID?
    @Binding var dropTargetTodoID: TodoItem.ID?
    @Binding var dropPlacement: TodoDropPlacement?
    let store: TodoStore

    func dropEntered(info: DropInfo) {
        updateDropTarget(info: info)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTodoID else {
            clearDropState()
            return false
        }

        let placement = placement(for: info)
        withAnimation(.easeInOut(duration: 0.16)) {
            if placement == .after {
                store.moveTodo(draggedID: draggedTodoID, after: targetTodo.id)
            } else {
                store.moveTodo(draggedID: draggedTodoID, before: targetTodo.id)
            }
        }

        clearDropState()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateDropTarget(info: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard dropTargetTodoID == targetTodo.id else { return }
        dropTargetTodoID = nil
        dropPlacement = nil
    }

    private func updateDropTarget(info: DropInfo) {
        guard let draggedTodoID, draggedTodoID != targetTodo.id else {
            if dropTargetTodoID == targetTodo.id {
                dropTargetTodoID = nil
                dropPlacement = nil
            }
            return
        }

        dropTargetTodoID = targetTodo.id
        dropPlacement = placement(for: info)
    }

    private func placement(for info: DropInfo) -> TodoDropPlacement {
        info.location.y > TodoWidgetLayout.rowHeight / 2 ? .after : .before
    }

    private func clearDropState() {
        draggedTodoID = nil
        dropTargetTodoID = nil
        dropPlacement = nil
    }
}

private struct TodoListEndDropDelegate: DropDelegate {
    @Binding var draggedTodoID: TodoItem.ID?
    @Binding var dropTargetTodoID: TodoItem.ID?
    @Binding var dropPlacement: TodoDropPlacement?
    let store: TodoStore

    func dropEntered(info: DropInfo) {
        guard draggedTodoID != nil else { return }

        dropTargetTodoID = nil
        dropPlacement = .end
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedTodoID else {
            clearDropState()
            return false
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            store.moveTodoToEnd(draggedID: draggedTodoID)
        }

        clearDropState()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if draggedTodoID != nil {
            dropTargetTodoID = nil
            dropPlacement = .end
        }
        return DropProposal(operation: .move)
    }

    private func clearDropState() {
        draggedTodoID = nil
        dropTargetTodoID = nil
        dropPlacement = nil
    }
}

private enum TodoDropPlacement {
    case before
    case after
    case end
}

private struct DropIndicator: View {
    var body: some View {
        Capsule()
            .fill(NotionDesign.Colors.primary)
            .frame(height: 2)
            .padding(.horizontal, 10)
    }
}

private struct AddTodoInlineRow: View {
    @Binding var title: String
    let commit: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.primary)

            TextField("새 할 일 추가...", text: $title)
                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
                .textFieldStyle(.plain)
                .onSubmit(commit)

            Button(action: commit) {
                Text("추가")
            }
            .buttonStyle(StartPillButtonStyle())

            Button(action: cancel) {
                Image(systemName: "xmark")
            }
            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.stone, size: 20, background: .clear))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(NotionDesign.Colors.surfaceSoft)
    }
}

private struct CheckCircle: View {
    let checked: Bool
    var tint: Color = NotionDesign.Colors.primary
    var size: CGFloat = 15

    var body: some View {
        ZStack {
            Circle()
                .fill(checked ? tint : .clear)
                .overlay {
                    Circle()
                        .stroke(checked ? tint : NotionDesign.Colors.hairline, lineWidth: 1.5)
                }

            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: max(size * 0.53, 6), weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ClickCaptureView: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> MouseClickView {
        let view = MouseClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: MouseClickView, context: Context) {
        nsView.action = action
    }
}

private struct TodoTextInteractionView: NSViewRepresentable {
    let payload: String
    let singleClick: () -> Void
    let doubleClick: () -> Void
    let beginDrag: () -> Void
    let endDrag: () -> Void

    func makeNSView(context: Context) -> TodoTextInteractionNSView {
        let view = TodoTextInteractionNSView()
        view.payload = payload
        view.action = singleClick
        view.doubleAction = doubleClick
        view.beginDrag = beginDrag
        view.endDrag = endDrag
        return view
    }

    func updateNSView(_ nsView: TodoTextInteractionNSView, context: Context) {
        nsView.payload = payload
        nsView.action = singleClick
        nsView.doubleAction = doubleClick
        nsView.beginDrag = beginDrag
        nsView.endDrag = endDrag
    }
}

private final class MouseClickView: NSView {
    var action: (() -> Void)?
    var doubleAction: (() -> Void)?
    private var isTrackingClick = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        isTrackingClick = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingClick else { return }
        isTrackingClick = false

        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            if event.clickCount >= 2 {
                doubleAction?()
            } else {
                action?()
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        isTrackingClick = false
    }
}

private final class TodoTextInteractionNSView: NSView, NSDraggingSource {
    var payload = ""
    var action: (() -> Void)?
    var doubleAction: (() -> Void)?
    var beginDrag: (() -> Void)?
    var endDrag: (() -> Void)?
    private var mouseDownEvent: NSEvent?
    private var didBeginDrag = false
    private let dragThreshold: CGFloat = 4

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didBeginDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, didBeginDrag == false else { return }

        let start = mouseDownEvent.locationInWindow
        let current = event.locationInWindow
        guard hypot(current.x - start.x, current.y - start.y) >= dragThreshold else { return }

        didBeginDrag = true
        beginDrag?()

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(payload, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: dragImage())

        beginDraggingSession(with: [draggingItem], event: mouseDownEvent, source: self)
        self.mouseDownEvent = nil
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            didBeginDrag = false
        }

        guard didBeginDrag == false else { return }

        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }

        if event.clickCount >= 2 {
            doubleAction?()
        } else {
            action?()
        }
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .move
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        mouseDownEvent = nil
        didBeginDrag = false
        endDrag?()
    }

    private func dragImage() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        NSColor.clear.setFill()
        bounds.fill()
        NSColor(calibratedRed: 0.34, green: 0.27, blue: 0.83, alpha: 0.14).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 3), xRadius: 6, yRadius: 6).fill()
        image.unlockFocus()
        return image
    }
}

private struct PomodoroProgressDots: View {
    let todo: TodoItem

    private var targetCount: Int {
        max(todo.targetPomodoros, 1)
    }

    private var overflowCount: Int {
        max(todo.completedPomodoros - targetCount, 0)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<targetCount, id: \.self) { index in
                Circle()
                    .fill(index < todo.completedPomodoros ? NotionDesign.Colors.primary : NotionDesign.Colors.hairline)
                    .frame(width: 5, height: 5)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(NotionDesign.Fonts.pretendard(size: 9, weight: .semibold))
                    .foregroundStyle(NotionDesign.Colors.success)
                    .padding(.horizontal, 4)
                    .frame(height: 14)
                    .background(NotionDesign.Colors.mint.opacity(0.70), in: Capsule())
            }
        }
        .help("\(todo.completedPomodoros)/\(todo.targetPomodoros) 수행")
    }
}

struct SettingsPanelView: View {
    @Bindable var store: TodoStore
    let setTodoWidgetDesktopMode: (Bool) -> Void
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            if store.isBlockedSitesPresented {
                BlockedSitesEditor(store: store)
            } else {
                settingsTabs

                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettings(
                            store: store,
                            setTodoWidgetDesktopMode: setTodoWidgetDesktopMode
                        )
                    case .timer:
                        TimerSettings(store: store)
                    case .alerts:
                        AlertSettings(store: store)
                    case .notion:
                        NotionSettings(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, SettingsPanelLayout.contentHorizontalPadding)
                .padding(.top, SettingsPanelLayout.contentTopPadding)
                .padding(.bottom, SettingsPanelLayout.contentBottomPadding)
            }
        }
        .frame(width: SettingsPanelLayout.contentWidth, height: SettingsPanelLayout.contentHeight)
        .background(NotionDesign.Colors.canvas)
        .clipShape(SettingsPanelLayout.shape)
        .compositingGroup()
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(NotionDesign.Panel.floatingShadowPadding)
        .frame(width: SettingsPanelLayout.windowWidth, height: SettingsPanelLayout.windowHeight)
    }

    private var sheetHeader: some View {
        PanelHeader(title: store.isBlockedSitesPresented ? "차단 사이트" : "환경설정") {
            if store.isBlockedSitesPresented {
                HStack(spacing: 4) {
                    Circle()
                        .fill(NotionDesign.Colors.error)
                        .frame(width: 6, height: 6)
                    Text("\(store.blockedSites.count)개 활성")
                        .font(NotionDesign.Fonts.pretendard(size: 11, weight: .semibold))
                        .foregroundStyle(NotionDesign.Colors.error)
                        .lineLimit(1)
                }
            } else {
                Color.clear
            }
        }
    }

    private var settingsTabs: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(NotionDesign.Fonts.pretendard(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? NotionDesign.Colors.charcoal : NotionDesign.Colors.steel)
                        .frame(maxWidth: .infinity)
                        .frame(height: SettingsPanelLayout.tabHeight)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selectedTab == tab ? NotionDesign.Colors.charcoal : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NotionDesign.Colors.hairline)
                .frame(height: 1)
        }
    }
}

enum SettingsPanelLayout {
    static let contentWidth: CGFloat = 360
    static let contentHeight: CGFloat = 486
    static let tabHeight: CGFloat = 36
    static let contentHorizontalPadding: CGFloat = 14
    static let contentTopPadding: CGFloat = 14
    static let contentBottomPadding: CGFloat = 14
    static let rowSpacing: CGFloat = 8
    static let rowHeight: CGFloat = 44
    static let sliderRowHeight: CGFloat = 78
    static let rowHorizontalPadding: CGFloat = 12
    static let trailingControlWidth: CGFloat = 64
    static let windowWidth = contentWidth + NotionDesign.Panel.floatingShadowPadding * 2
    static let windowHeight = contentHeight + NotionDesign.Panel.floatingShadowPadding * 2
    static let shape = RoundedRectangle(cornerRadius: NotionDesign.Radius.widget, style: .continuous)
}

private enum SettingsTab: CaseIterable {
    case general
    case timer
    case alerts
    case notion

    var title: String {
        switch self {
        case .general:
            "일반"
        case .timer:
            "타이머"
        case .alerts:
            "알림"
        case .notion:
            "노션"
        }
    }
}

private struct GeneralSettings: View {
    @Bindable var store: TodoStore
    let setTodoWidgetDesktopMode: (Bool) -> Void

    var body: some View {
        VStack(spacing: SettingsPanelLayout.rowSpacing) {
            SettingsShortcutRow(title: "뽀모도로 시작", shortcut: "⌘⌥P")
            SettingsShortcutRow(title: "새 투두 메모", shortcut: "⌘M")

            Button {
                store.isBlockedSitesPresented = true
            } label: {
                SettingsRowShell {
                    Text("차단 관리")
                    Spacer()
                    SettingsTrailingSlot {
                        ShortcutBadge("⌘⇧B")
                    }
                }
            }
            .buttonStyle(.plain)
            .help("차단할 웹사이트")

            SettingsRowShell {
                Text("배경 위젯 모드")
                Spacer()
                SettingsTrailingSlot {
                    Toggle("", isOn: Binding(
                        get: { store.isTodoWidgetDesktopModeEnabled },
                        set: { setTodoWidgetDesktopMode($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
            .help("끄면 투두 위젯을 일반 창 레벨로 표시")

            SettingsRowShell {
                Text("로그인 시 자동 실행")
                Spacer()
                SettingsTrailingSlot {
                    Toggle("", isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct TimerSettings: View {
    @Bindable var store: TodoStore

    var body: some View {
        VStack(spacing: SettingsPanelLayout.rowSpacing) {
            SettingsSliderRow(
                title: "집중 시간",
                value: Binding(
                    get: { Double(store.defaultPomodoroMinutes) },
                    set: { store.setDefaultPomodoroMinutes(Int($0)) }
                ),
                range: 5...60,
                step: 5,
                suffix: "분"
            )

            SettingsSliderRow(
                title: "휴식 시간",
                value: Binding(
                    get: { Double(store.defaultBreakMinutes) },
                    set: { store.setDefaultBreakMinutes(Int($0)) }
                ),
                range: 1...30,
                step: 1,
                suffix: "분"
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct AlertSettings: View {
    @Bindable var store: TodoStore

    var body: some View {
        VStack(spacing: SettingsPanelLayout.rowSpacing) {
            SettingsRowShell {
                Text("타이머 종료 알림")
                Spacer()
                SettingsTrailingSlot {
                    Toggle("", isOn: Binding(
                        get: { store.notificationsEnabled },
                        set: { store.setNotificationsEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }

            SettingsRowShell {
                Text("알림음")
                Spacer()
                SettingsTrailingSlot {
                    Text("Glass")
                        .font(NotionDesign.Fonts.captionBold)
                        .foregroundStyle(NotionDesign.Colors.steel)
                }
            }

            SettingsMusicPickerRow(store: store)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct NotionSettings: View {
    @Bindable var store: TodoStore

    private let syncIntervals = [30, 60, 300]

    var body: some View {
        VStack(spacing: SettingsPanelLayout.rowSpacing) {
            SettingsRowShell {
                Text("노션 연동")
                Spacer()
                SettingsTrailingSlot {
                    Toggle("", isOn: Binding(
                        get: { store.notionEnabled },
                        set: { store.setNotionEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }

            SettingsRowShell {
                Text("자동 동기화")
                Spacer()
                SettingsTrailingSlot {
                    Toggle("", isOn: Binding(
                        get: { store.notionAutoSyncEnabled },
                        set: { store.setNotionAutoSyncEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }

            SettingsRowShell {
                Text("동기화 간격")
                Spacer()
                Picker("", selection: Binding(
                    get: { store.notionAutoSyncIntervalSeconds },
                    set: { store.setNotionAutoSyncIntervalSeconds($0) }
                )) {
                    ForEach(syncIntervals, id: \.self) { seconds in
                        Text(intervalLabel(seconds)).tag(seconds)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 104, alignment: .trailing)
                .disabled(!store.notionAutoSyncEnabled)
            }

            SettingsInputRow(
                title: "DB URL 또는 ID",
                placeholder: "notion.so/...",
                text: $store.notionDatabaseID,
                isSecure: false,
                submit: store.saveNotionSettings
            )

            SettingsInputRow(
                title: "Integration Token",
                placeholder: "노션 integration token",
                text: $store.notionToken,
                isSecure: true,
                submit: store.saveNotionSettings
            )

            HStack(spacing: 8) {
                Button {
                    store.refreshNotionTodosNow()
                } label: {
                    HStack(spacing: 6) {
                        if store.isNotionSyncing {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.72)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(store.isNotionSyncing ? "가져오는 중" : "가져오기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(NotionSyncButtonStyle())
                .disabled(store.isNotionSyncing)

                Button {
                    store.saveNotionSettings()
                    store.configureNotionAutoSync()
                } label: {
                    Text("저장")
                        .frame(width: 54)
                }
                .buttonStyle(NotionSyncButtonStyle(isSecondary: true))
            }

            Text(statusText)
                .font(NotionDesign.Fonts.pretendard(size: 11, weight: .regular))
                .foregroundStyle(statusColor)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var statusText: String {
        if !store.notionSyncMessage.isEmpty {
            return store.notionSyncMessage
        }
        if let syncedAt = store.notionLastSyncedAt {
            return "마지막 동기화 \(Formatters.relativeTime(syncedAt))"
        }
        return "노션 DB를 앱에 공유한 뒤 토큰과 DB URL을 입력하세요."
    }

    private var statusColor: Color {
        store.notionSyncMessage.contains("실패") ? NotionDesign.Colors.error : NotionDesign.Colors.steel
    }

    private func intervalLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)초" : "\(seconds / 60)분"
    }
}

private struct SettingsInputRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NotionDesign.Fonts.pretendard(size: 12, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.charcoal)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(NotionDesign.Fonts.pretendard(size: 12, weight: .regular))
            .textFieldStyle(.plain)
            .onSubmit(submit)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(NotionDesign.Colors.surfaceSoft, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
        }
        .padding(.horizontal, SettingsPanelLayout.rowHorizontalPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium))
    }
}

private struct SettingsMusicPickerRow: View {
    @Bindable var store: TodoStore

    private var selection: Binding<String> {
        Binding(
            get: { store.selectedFocusMusicID ?? "" },
            set: { newValue in
                store.setSelectedFocusMusic(FocusMusicTrack(rawValue: newValue))
            }
        )
    }

    var body: some View {
        SettingsRowShell {
            Text("집중 음악")
            Spacer()
            Picker("", selection: selection) {
                Text("선택 안함").tag("")
                ForEach(FocusMusicTrack.allCases) { track in
                    Text(track.title).tag(track.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 158, alignment: .trailing)
        }
    }
}

private struct NotionSyncButtonStyle: ButtonStyle {
    var isSecondary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.pretendard(size: 12, weight: .semibold))
            .foregroundStyle(isSecondary ? NotionDesign.Colors.charcoal : Color.white)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .background(
                isSecondary ? NotionDesign.Colors.surface : NotionDesign.Colors.charcoal,
                in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: isSecondary ? 1 : 0)
            }
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct SettingsShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        SettingsRowShell {
            Text(title)
            Spacer()
            SettingsTrailingSlot {
                ShortcutBadge(shortcut)
            }
        }
    }
}

private struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(NotionDesign.Fonts.pretendard(size: 13, weight: .medium))
                    .foregroundStyle(NotionDesign.Colors.charcoal)
                Spacer()
                SettingsTrailingSlot {
                    Text("\(Int(value))\(suffix)")
                        .font(NotionDesign.Fonts.captionBold)
                        .foregroundStyle(NotionDesign.Colors.charcoal)
                }
            }

            Slider(value: $value, in: range, step: step)
                .tint(NotionDesign.Colors.primary)
        }
        .padding(.horizontal, SettingsPanelLayout.rowHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: SettingsPanelLayout.sliderRowHeight)
        .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium))
    }
}

private struct SettingsTrailingSlot<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: SettingsPanelLayout.trailingControlWidth, alignment: .trailing)
    }
}

private struct SettingsRowShell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 10) {
            content()
        }
        .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
        .foregroundStyle(NotionDesign.Colors.charcoal)
        .padding(.horizontal, SettingsPanelLayout.rowHorizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: SettingsPanelLayout.rowHeight)
        .background(NotionDesign.Colors.surface, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.medium))
    }
}

private struct BlockedSitesEditor: View {
    @Bindable var store: TodoStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NotionDesign.Colors.primary)
                Text("뽀모도로 진행 중 자동 활성화됩니다")
                    .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
                    .foregroundStyle(NotionDesign.Colors.slate)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NotionDesign.Colors.surface)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NotionDesign.Colors.hairlineSoft)
                    .frame(height: 1)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.blockedSites, id: \.self) { site in
                        HStack(spacing: 8) {
                            Text(siteCategory(for: site))
                                .font(NotionDesign.Fonts.pretendard(size: 10, weight: .semibold))
                                .foregroundStyle(categoryColor(for: site))
                                .padding(.horizontal, 6)
                                .frame(height: 18)
                                .background(categoryColor(for: site).opacity(0.14), in: RoundedRectangle(cornerRadius: 4))

                            Text(site)
                                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
                                .foregroundStyle(NotionDesign.Colors.charcoal)
                                .lineLimit(1)

                            Spacer()

                            Button {
                                store.deleteBlockedSite(site)
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(DesignIconButtonStyle(tint: NotionDesign.Colors.stone, size: 20, background: .clear))
                            .help("삭제")
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                    }
                }
            }

            HStack(spacing: 6) {
                TextField("example.com", text: $store.newBlockedSite)
                    .font(NotionDesign.Fonts.pretendard(size: 13, weight: .regular))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(NotionDesign.Colors.surfaceSoft, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
                    .overlay {
                        RoundedRectangle(cornerRadius: NotionDesign.Radius.small)
                            .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
                    }
                    .onSubmit { store.addBlockedSite() }

                Button {
                    store.addBlockedSite()
                } label: {
                    Text("추가")
                }
                .buttonStyle(AddSiteButtonStyle())
                .help("차단 사이트 추가")
            }
            .padding(12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NotionDesign.Colors.hairlineSoft)
                    .frame(height: 1)
            }
        }
    }

    private func siteCategory(for site: String) -> String {
        if site.contains("youtube") || site.contains("netflix") { return "영상" }
        if site.contains("naver") || site.contains("daum") { return "포털" }
        if site.contains("instagram") || site.contains("twitter") || site.contains("x.com") { return "SNS" }
        return "기타"
    }

    private func categoryColor(for site: String) -> Color {
        switch siteCategory(for: site) {
        case "SNS":
            return NotionDesign.Colors.primary
        case "영상":
            return NotionDesign.Colors.error
        case "포털":
            return NotionDesign.Colors.success
        default:
            return NotionDesign.Colors.steel
        }
    }
}

private struct WindowDragArea: NSViewRepresentable {
    let isLocked: Bool
    let onMoved: (CGPoint) -> Void

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.isLocked = isLocked
        view.onMoved = onMoved
        return view
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.isLocked = isLocked
        nsView.onMoved = onMoved
    }
}

private final class DragHandleView: NSView {
    var isLocked = false
    var onMoved: ((CGPoint) -> Void)?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        guard let window, !isLocked else { return }
        NSCursor.closedHand.set()
        defer { NSCursor.openHand.set() }
        window.isMovable = true
        window.performDrag(with: event)
        publishCurrentOrigin()
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
        publishCurrentOrigin()
    }

    private func publishCurrentOrigin() {
        guard let origin = window?.frame.origin else { return }
        onMoved?(CGPoint(x: origin.x, y: origin.y))
    }
}

private struct WindowResizeArea: NSViewRepresentable {
    var mode: ResizeHandleMode = .bottomRight

    func makeNSView(context: Context) -> ResizeHandleView {
        let view = ResizeHandleView()
        view.mode = mode
        return view
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {
        nsView.mode = mode
    }
}

private enum ResizeHandleMode {
    case right
    case bottom
    case bottomRight
}

private final class ResizeHandleView: NSView {
    var mode: ResizeHandleMode = .bottomRight
    private var initialMouseLocation = NSPoint.zero
    private var initialWindowFrame = NSRect.zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: cursor)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        cursor.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let deltaX = mouseLocation.x - initialMouseLocation.x
        let deltaY = mouseLocation.y - initialMouseLocation.y
        let minSize = window.minSize
        let newWidth = mode.resizesWidth
            ? max(minSize.width, initialWindowFrame.width + deltaX)
            : initialWindowFrame.width
        let newHeight = mode.resizesHeight
            ? max(minSize.height, initialWindowFrame.height - deltaY)
            : initialWindowFrame.height
        let newOriginY = initialWindowFrame.maxY - newHeight

        window.setFrame(
            NSRect(
                x: initialWindowFrame.minX,
                y: newOriginY,
                width: newWidth,
                height: newHeight
            ),
            display: true
        )
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    private var cursor: NSCursor {
        switch mode {
        case .right, .bottomRight:
            return .resizeLeftRight
        case .bottom:
            return .resizeUpDown
        }
    }
}

private extension ResizeHandleMode {
    var resizesWidth: Bool {
        self == .right || self == .bottomRight
    }

    var resizesHeight: Bool {
        self == .bottom || self == .bottomRight
    }
}

private struct ShortcutBadge: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
            .foregroundStyle(NotionDesign.Colors.slate)
            .padding(.horizontal, 5)
            .frame(height: 18)
            .background(NotionDesign.Colors.surfaceSoft, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(NotionDesign.Colors.hairline, lineWidth: 1)
            }
    }
}

private struct DesignIconButtonStyle: ButtonStyle {
    var tint: Color
    var size: CGFloat
    var background: Color = NotionDesign.Colors.surface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: max(10, size * 0.48), weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(configuration.isPressed ? NotionDesign.Colors.hairline : background, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
            .opacity(configuration.isPressed ? 0.76 : 1)
    }
}

private struct StartPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.pretendard(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(configuration.isPressed ? NotionDesign.Colors.primaryPressed : NotionDesign.Colors.primary, in: RoundedRectangle(cornerRadius: 4))
            .shadow(color: NotionDesign.Colors.primary.opacity(0.30), radius: 4, x: 0, y: 1)
    }
}

private struct FooterLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.pretendard(size: 11, weight: .medium))
            .foregroundStyle(NotionDesign.Colors.stone)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private struct AddSiteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotionDesign.Fonts.pretendard(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(configuration.isPressed ? NotionDesign.Colors.primaryPressed : NotionDesign.Colors.primary, in: RoundedRectangle(cornerRadius: NotionDesign.Radius.small))
    }
}
