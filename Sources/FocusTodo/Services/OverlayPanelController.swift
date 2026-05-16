import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController<Content: View> {
    enum Chrome {
        case borderless
        case nativeControls
    }

    private var panel: NSPanel?
    private var panelDelegate: PanelWindowDelegate?
    private var title: String
    private let size: NSSize
    private let minimumSize: NSSize
    private let nonActivating: Bool
    private let level: NSWindow.Level
    private let chrome: Chrome
    private let joinsAllSpaces: Bool
    private let movableByWindowBackground: Bool
    private let hasShadow: Bool
    private let hidesOnDeactivate: Bool
    private var isResizable: Bool
    private let nativeControlHeaderHeight: CGFloat
    private let usesCustomNativeHeader: Bool
    private let onClose: (() -> Void)?
    private let content: () -> Content

    init(
        title: String,
        size: NSSize,
        minimumSize: NSSize? = nil,
        nonActivating: Bool = true,
        level: NSWindow.Level = .screenSaver,
        chrome: Chrome = .borderless,
        joinsAllSpaces: Bool = true,
        movableByWindowBackground: Bool = true,
        hasShadow: Bool? = nil,
        hidesOnDeactivate: Bool = false,
        isResizable: Bool = false,
        nativeControlHeaderHeight: CGFloat = NotionDesign.Panel.headerHeight,
        usesCustomNativeHeader: Bool = true,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.size = size
        self.minimumSize = minimumSize ?? size
        self.nonActivating = nonActivating
        self.level = level
        self.chrome = chrome
        self.joinsAllSpaces = joinsAllSpaces
        self.movableByWindowBackground = movableByWindowBackground
        self.hasShadow = hasShadow ?? (chrome == .nativeControls)
        self.hidesOnDeactivate = hidesOnDeactivate
        self.isResizable = isResizable
        self.nativeControlHeaderHeight = nativeControlHeaderHeight
        self.usesCustomNativeHeader = usesCustomNativeHeader
        self.onClose = onClose
        self.content = content
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var window: NSWindow? {
        panel
    }

    func show(position: NSPoint? = nil) {
        let panel = existingOrCreatePanel()
        if let position {
            panel.setFrameOrigin(position)
        } else if panel.frame == .zero {
            panel.center()
        }
        if nonActivating {
            panel.orderFrontRegardless()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
        if chrome == .nativeControls, usesCustomNativeHeader {
            configureNativeWindowButtons(for: panel)
        }
        if hasShadow {
            panel.invalidateShadow()
        }
    }

    func setTitle(_ title: String) {
        self.title = title
        panel?.title = title
    }

    func setResizable(_ enabled: Bool) {
        isResizable = enabled
        guard let panel else { return }

        if enabled {
            panel.styleMask.insert(.resizable)
        } else {
            panel.styleMask.remove(.resizable)
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func existingOrCreatePanel() -> NSPanel {
        if let panel {
            return panel
        }

        var styleMask: NSWindow.StyleMask = []
        if chrome == .borderless || usesCustomNativeHeader {
            styleMask.insert(.fullSizeContentView)
        }
        if nonActivating {
            styleMask.insert(.nonactivatingPanel)
        }
        if chrome == .nativeControls {
            styleMask.insert(.titled)
            styleMask.insert(.closable)
            styleMask.insert(.miniaturizable)
        }
        if isResizable {
            styleMask.insert(.resizable)
        }

        let panel = AlwaysOnTopPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        let hostingController = ZeroSafeAreaHostingController(rootView: content())
        let rootController = PanelRootViewController(hostingController: hostingController, size: size)

        panel.title = title
        panel.contentViewController = rootController
        panel.isReleasedWhenClosed = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.isFloatingPanel = level.rawValue > NSWindow.Level.normal.rawValue
        panel.hidesOnDeactivate = hidesOnDeactivate
        panel.becomesKeyOnlyIfNeeded = nonActivating
        panel.level = level
        panel.collectionBehavior = collectionBehavior()
        panel.titleVisibility = usesCustomNativeHeader ? .hidden : .visible
        panel.titlebarAppearsTransparent = usesCustomNativeHeader
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.hasShadow = hasShadow
        panel.isMovableByWindowBackground = movableByWindowBackground
        panel.minSize = minimumSize
        panel.setContentSize(size)
        panel.center()

        if chrome == .nativeControls, usesCustomNativeHeader {
            configureNativeWindowButtons(for: panel)
        }

        let panelDelegate = PanelWindowDelegate(
            close: { [weak panel, onClose] in
                onClose?()
                panel?.orderOut(nil)
            },
            didResize: { [weak self, weak panel] in
                guard let panel else { return }
                if self?.usesCustomNativeHeader == true {
                    self?.configureNativeWindowButtons(for: panel)
                }
                panel.invalidateShadow()
            }
        )
        panel.delegate = panelDelegate
        self.panelDelegate = panelDelegate
        self.panel = panel
        return panel
    }

    private func configureNativeWindowButtons(for panel: NSPanel) {
        guard let closeButton = panel.standardWindowButton(.closeButton),
              let miniaturizeButton = panel.standardWindowButton(.miniaturizeButton),
              let contentView = panel.contentView else {
            return
        }

        closeButton.isHidden = false
        miniaturizeButton.isHidden = false
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        if closeButton.superview !== contentView {
            closeButton.removeFromSuperview()
            miniaturizeButton.removeFromSuperview()
            contentView.addSubview(closeButton)
            contentView.addSubview(miniaturizeButton)
        }

        let leftInset: CGFloat = 18
        let spacing: CGFloat = 7
        let headerCenterY = contentView.bounds.maxY - nativeControlHeaderHeight / 2
        let buttonY = headerCenterY - closeButton.frame.height / 2

        closeButton.frame.origin = NSPoint(x: leftInset, y: buttonY)
        miniaturizeButton.frame.origin = NSPoint(
            x: closeButton.frame.maxX + spacing,
            y: buttonY
        )

        closeButton.autoresizingMask = [.minYMargin]
        miniaturizeButton.autoresizingMask = [.minYMargin]
    }

    private func collectionBehavior() -> NSWindow.CollectionBehavior {
        var behavior: NSWindow.CollectionBehavior = [.stationary, .ignoresCycle]
        if joinsAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }
        if level.rawValue > NSWindow.Level.normal.rawValue {
            behavior.insert(.fullScreenAuxiliary)
        }
        return behavior
    }
}

private final class AlwaysOnTopPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ZeroSafeAreaHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = ZeroSafeAreaHostingView(rootView: rootView)
    }
}

private final class ZeroSafeAreaHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }
}

private final class PanelRootViewController<Content: View>: NSViewController {
    private let hostingController: NSHostingController<Content>
    private let size: NSSize

    init(hostingController: NSHostingController<Content>, size: NSSize) {
        self.hostingController = hostingController
        self.size = size
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(hostingController)
        let hostedView = hostingController.view
        hostedView.frame = view.bounds
        hostedView.autoresizingMask = [.width, .height]
        hostedView.wantsLayer = true
        hostedView.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(hostedView)
    }
}

private final class PanelWindowDelegate: NSObject, NSWindowDelegate {
    private let close: () -> Void
    private let didResize: () -> Void

    init(close: @escaping () -> Void, didResize: @escaping () -> Void) {
        self.close = close
        self.didResize = didResize
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }

    func windowDidResize(_ notification: Notification) {
        didResize()
    }
}
