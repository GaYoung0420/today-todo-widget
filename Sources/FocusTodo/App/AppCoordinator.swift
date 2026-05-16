import AppKit
import CoreGraphics
import SwiftUI

@MainActor
final class AppCoordinator {
    let store = TodoStore()
    let blocker = BrowserBlocker()
    let session: PomodoroSession

    private var todoPanel: OverlayPanelController<ContentView>?
    private var pomodoroPanel: OverlayPanelController<PomodoroWidgetView>?
    private var memoPanel: OverlayPanelController<MemoPanelView>?
    private var settingsPanel: OverlayPanelController<SettingsPanelView>?
    private var hotKeyManager: HotKeyManager?
    private var statusBarController: StatusBarController?

    init() {
        session = PomodoroSession(blocker: blocker)
        session.onFocusCompleted = { [weak self] todo in
            self?.store.completePomodoro(for: todo) ?? todo
        }
        session.shouldPlayAlert = { [weak self] in
            self?.store.notificationsEnabled ?? true
        }
        session.selectedFocusMusic = { [weak self] in
            guard let id = self?.store.selectedFocusMusicID else { return nil }
            return FocusMusicTrack(rawValue: id)
        }
    }

    func start() {
        NSApp.setActivationPolicy(.accessory)

        todoPanel = OverlayPanelController(
            title: "Focus Todo",
            size: NSSize(width: TodoWidgetLayout.windowWidth, height: TodoWidgetLayout.windowHeight),
            minimumSize: NSSize(width: TodoWidgetLayout.windowWidth, height: TodoWidgetLayout.windowHeight),
            nonActivating: false,
            level: NSWindow.Level(rawValue: -1),
            chrome: .borderless,
            joinsAllSpaces: false,
            movableByWindowBackground: false,
            isResizable: !store.isTodoWidgetPositionLocked
        ) {
            ContentView(
                store: self.store,
                session: self.session,
                showPomodoro: { [weak self] todo in self?.startPomodoro(todo) },
                showMemo: { [weak self] todo in self?.showMemo(todo) },
                createTodoAndShowMemo: { [weak self] in self?.createTodoAndShowMemo() },
                setTodoWidgetLocked: { [weak self] locked in self?.setTodoWidgetLocked(locked) },
                showSettings: { [weak self] showBlockedSites in self?.showSettings(blockedSites: showBlockedSites) }
            )
        }

        pomodoroPanel = OverlayPanelController(
            title: "Pomodoro",
            size: NSSize(width: PomodoroWidgetLayout.windowWidth, height: PomodoroWidgetLayout.windowHeight),
            nonActivating: true,
            level: .screenSaver,
            chrome: .borderless
        ) {
            PomodoroWidgetView(
                session: self.session,
                store: self.store,
                close: { [weak self] in self?.closePomodoro() }
            )
        }

        memoPanel = OverlayPanelController(
            title: "메모",
            size: NSSize(width: MemoPanelLayout.windowWidth, height: MemoPanelLayout.windowHeight),
            minimumSize: NSSize(width: MemoPanelLayout.minimumWindowWidth, height: MemoPanelLayout.minimumWindowHeight),
            nonActivating: false,
            level: .screenSaver,
            chrome: .borderless,
            isResizable: true
        ) {
            MemoPanelView(store: self.store)
        }

        settingsPanel = OverlayPanelController(
            title: "환경설정",
            size: NSSize(width: SettingsPanelLayout.windowWidth, height: SettingsPanelLayout.windowHeight),
            nonActivating: false,
            level: .screenSaver,
            chrome: .borderless,
            onClose: { [weak self] in self?.store.isBlockedSitesPresented = false }
        ) {
            SettingsPanelView(store: self.store)
        }

        hotKeyManager = HotKeyManager { [weak self] in
            self?.createTodoAndShowMemo()
        }
        hotKeyManager?.register()
        statusBarController = StatusBarController(coordinator: self)

        showTodoPanel()
    }

    func showTodoPanel() {
        guard let screen = NSScreen.main else {
            todoPanel?.show()
            return
        }

        let origin: NSPoint
        if let saved = store.todoWidgetPosition {
            origin = NSPoint(x: saved.x, y: saved.y)
        } else {
            let visible = screen.visibleFrame
            origin = NSPoint(
                x: visible.minX,
                y: visible.maxY - TodoWidgetLayout.windowHeight
            )
        }
        todoPanel?.show(position: origin)
        todoPanel?.setResizable(!store.isTodoWidgetPositionLocked)
    }

    func startPomodoro(_ todo: TodoItem) {
        let currentTodo = store.binding(for: todo)
        store.selectedTodoID = currentTodo.id
        session.start(todo: currentTodo, blockedSites: store.blockedSites)
        statusBarController?.refreshStatusItem()

        guard let screen = NSScreen.main else {
            pomodoroPanel?.show()
            return
        }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - PomodoroWidgetLayout.windowWidth,
            y: visible.maxY - PomodoroWidgetLayout.windowHeight
        )
        pomodoroPanel?.show(position: origin)
    }

    func closePomodoro() {
        session.pause()
        pomodoroPanel?.hide()
        statusBarController?.refreshStatusItem()
    }

    func showSettings(blockedSites: Bool = false) {
        store.isBlockedSitesPresented = blockedSites
        settingsPanel?.setTitle(blockedSites ? "차단 사이트" : "환경설정")
        settingsPanel?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func showMemo(_ todo: TodoItem) {
        store.selectedTodoID = todo.id
        memoPanel?.show()
        NSApp.activate(ignoringOtherApps: true)
    }

    func createTodoAndShowMemo() {
        let todo = store.addQuickMemoTodo()
        showTodoPanel()
        showMemo(todo)
    }

    func setTodoWidgetLocked(_ locked: Bool) {
        store.setTodoWidgetPositionLocked(locked)
        todoPanel?.setResizable(!locked)
    }

    func toggleMemoForSelection() {
        if memoPanel?.isVisible == true {
            memoPanel?.hide()
        } else if let todo = store.selectedTodo {
            showMemo(todo)
        }
    }
}
