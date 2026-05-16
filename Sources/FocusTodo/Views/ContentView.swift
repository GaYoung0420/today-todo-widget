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
            todoList
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

            Text("오늘 할 일")
                .font(NotionDesign.Fonts.pretendard(size: 13, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.charcoal)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(store.todos.filter(\.isDone).count)/\(store.todos.count)")
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
                ForEach(store.todos) { todo in
                    TodoRow(
                        todo: todo,
                        isHovered: hoveredTodoID == todo.id,
                        isSelected: store.selectedTodoID == todo.id,
                        isActive: session.activeTodo?.id == todo.id,
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
        var updated = todo
        updated.isDone.toggle()
        store.updateTodo(updated)
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

            if !store.isTodoWidgetPositionLocked {
                WindowDragArea { origin in
                    store.setTodoWidgetPosition(x: origin.x, y: origin.y)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack {
                    Spacer()
                    WindowResizeArea()
                        .frame(width: TodoWidgetLayout.handleWidth, height: 34)
                }
            }
        }
        .frame(width: TodoWidgetLayout.handleWidth)
        .frame(minHeight: TodoWidgetLayout.contentHeight, maxHeight: .infinity)
        .contentShape(Rectangle())
        .help(store.isTodoWidgetPositionLocked ? "위치와 크기가 잠겨 있습니다" : "드래그해서 이동하거나 가장자리에서 크기 조절")
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

    var body: some View {
        VStack(spacing: 0) {
            header
            todoList
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

            Text("오늘 할 일")
                .font(NotionDesign.Fonts.pretendard(size: 15, weight: .semibold))
                .foregroundStyle(NotionDesign.Colors.charcoal)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text("\(store.todos.filter(\.isDone).count)/\(store.todos.count)")
                .font(NotionDesign.Fonts.pretendard(size: 12, weight: .medium))
                .foregroundStyle(NotionDesign.Colors.stone)
                .monospacedDigit()

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
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
                ForEach(store.todos) { todo in
                    TodoRow(
                        todo: todo,
                        isHovered: hoveredTodoID == todo.id,
                        isSelected: store.selectedTodoID == todo.id,
                        isActive: session.activeTodo?.id == todo.id,
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
        var updated = todo
        updated.isDone.toggle()
        store.updateTodo(updated)
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
    static let contentHeight: CGFloat = 240
    static let rowHeight: CGFloat = 38
    static let handleWidth: CGFloat = 18
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

private struct AlwaysVisibleVerticalScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
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

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller?.controlSize = .small
        context.coordinator.hostingView?.rootView = AnyView(content)
    }

    final class Coordinator {
        var hostingView: NSHostingView<AnyView>?
    }
}

private struct TodoRow: View {
    let todo: TodoItem
    let isHovered: Bool
    let isSelected: Bool
    let isActive: Bool
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
                    VStack(alignment: .leading, spacing: 1) {
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
                        }

                        if isActive {
                            Text("진행 중")
                                .font(NotionDesign.Fonts.pretendard(size: 10, weight: .semibold))
                                .foregroundStyle(NotionDesign.Colors.primary)
                        }
                    }

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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 15, height: 15)
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
                        GeneralSettings(store: store)
                    case .timer:
                        TimerSettings(store: store)
                    case .alerts:
                        AlertSettings(store: store)
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
    static let contentWidth: CGFloat = 320
    static let contentHeight: CGFloat = 342
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

    var title: String {
        switch self {
        case .general:
            "일반"
        case .timer:
            "타이머"
        case .alerts:
            "알림"
        }
    }
}

private struct GeneralSettings: View {
    @Bindable var store: TodoStore

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
    let onMoved: (CGPoint) -> Void

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.onMoved = onMoved
        return view
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.onMoved = onMoved
    }
}

private final class DragHandleView: NSView {
    var onMoved: ((CGPoint) -> Void)?
    private var initialMouseLocation = NSPoint.zero
    private var initialWindowOrigin = NSPoint.zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window.frame.origin
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - initialMouseLocation.x
        let deltaY = currentMouseLocation.y - initialMouseLocation.y
        window.setFrameOrigin(NSPoint(
            x: initialWindowOrigin.x + deltaX,
            y: initialWindowOrigin.y + deltaY
        ))
    }

    override func mouseUp(with event: NSEvent) {
        guard let origin = window?.frame.origin else { return }
        NSCursor.openHand.set()
        onMoved?(CGPoint(x: origin.x, y: origin.y))
    }
}

private struct WindowResizeArea: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeHandleView {
        ResizeHandleView()
    }

    func updateNSView(_ nsView: ResizeHandleView, context: Context) {}
}

private final class ResizeHandleView: NSView {
    private var initialMouseLocation = NSPoint.zero
    private var initialWindowFrame = NSRect.zero

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowFrame = window.frame
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let deltaX = mouseLocation.x - initialMouseLocation.x
        let deltaY = mouseLocation.y - initialMouseLocation.y
        let minSize = window.minSize
        let newWidth = max(minSize.width, initialWindowFrame.width + deltaX)
        let newHeight = max(minSize.height, initialWindowFrame.height - deltaY)
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
