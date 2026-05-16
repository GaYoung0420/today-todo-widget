import AppKit
import SwiftUI

@MainActor
final class FocusTodoAppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppFontRegistry.registerBundledFonts()
        coordinator.start()
    }
}

@main
struct FocusTodoApp: App {
    @NSApplicationDelegateAdaptor(FocusTodoAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
