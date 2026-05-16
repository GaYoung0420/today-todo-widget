import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var coordinator: AppCoordinator?
    private var refreshTimer: Timer?
    private var menuTodoPopover: NSPopover?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        refreshStatusItem()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func refreshStatusItem() {
        guard let button = statusItem.button,
              let coordinator else {
            return
        }

        if let todo = coordinator.session.activeTodo {
            button.image = nil
            button.title = "\(menuBarTodoTitle(todo.title)) \(Formatters.timeRemaining(coordinator.session.remainingSeconds))"
        } else {
            button.title = ""
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Focus Todo")
            button.imagePosition = .imageOnly
        }

        button.toolTip = "Focus Todo"
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatusItem()
            }
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            if menuTodoPopover?.isShown == true {
                closeMenuTodoPopover()
            } else {
                showMenuTodoPopover()
            }
            refreshStatusItem()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        addMenuItem("투두 창 열기", action: #selector(showMenuTodoFromMenu), to: menu)
        addMenuItem("투두 위젯 보이기", action: #selector(showTodoWidgetFromMenu), to: menu)

        if coordinator?.store.selectedTodo != nil {
            addMenuItem("선택한 투두 뽀모도로", action: #selector(startPomodoroFromMenu), to: menu)
            addMenuItem("선택한 투두 메모", action: #selector(showMemoFromMenu), to: menu)
        }

        menu.addItem(.separator())
        addMenuItem("종료", action: #selector(quitFromMenu), to: menu)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func showMenuTodoFromMenu() {
        showMenuTodoPopover()
        refreshStatusItem()
    }

    @objc private func showTodoWidgetFromMenu() {
        coordinator?.showTodoPanel()
        refreshStatusItem()
    }

    @objc private func startPomodoroFromMenu() {
        guard let todo = coordinator?.store.selectedTodo else { return }

        coordinator?.startPomodoro(todo)
        refreshStatusItem()
    }

    @objc private func showMemoFromMenu() {
        guard let todo = coordinator?.store.selectedTodo else { return }

        coordinator?.showMemo(todo)
        refreshStatusItem()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func showMenuTodoPopover() {
        guard let button = statusItem.button,
              let coordinator else {
            return
        }

        let popover = existingOrCreateMenuTodoPopover(coordinator: coordinator)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        button.highlight(true)
    }

    private func closeMenuTodoPopover() {
        menuTodoPopover?.close()
        statusItem.button?.highlight(false)
    }

    private func existingOrCreateMenuTodoPopover(coordinator: AppCoordinator) -> NSPopover {
        if let menuTodoPopover {
            return menuTodoPopover
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: MenuTodoPanelLayout.windowWidth, height: MenuTodoPanelLayout.windowHeight)
        popover.contentViewController = NSHostingController(
            rootView: MenuTodoPanelView(
                store: coordinator.store,
                session: coordinator.session,
                showPomodoro: { [weak coordinator] todo in coordinator?.startPomodoro(todo) },
                showMemo: { [weak coordinator] todo in coordinator?.showMemo(todo) },
                createTodoAndShowMemo: { [weak coordinator] in coordinator?.createTodoAndShowMemo() },
                showSettings: { [weak coordinator] showBlockedSites in coordinator?.showSettings(blockedSites: showBlockedSites) },
                close: { [weak self] in self?.closeMenuTodoPopover() }
            )
        )
        popover.delegate = self
        menuTodoPopover = popover
        return popover
    }

    private func menuBarTodoTitle(_ title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.count > 16 else {
            return trimmedTitle.isEmpty ? "뽀모도로" : trimmedTitle
        }

        return "\(trimmedTitle.prefix(16))..."
    }

}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }
}
