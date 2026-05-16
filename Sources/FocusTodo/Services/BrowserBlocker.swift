import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class BrowserBlocker {
    var lastBlockedURL: String?
    var authorizationHint: String?
    var currentBlockedSites: [String] { blockedSites }

    private var blockedSites: [String] = []
    private var timer: Timer?

    func start(blockedSites: [String]) {
        self.blockedSites = blockedSites
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }

        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.inspectFrontBrowser()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastBlockedURL = nil
    }

    private func inspectFrontBrowser() {
        guard !blockedSites.isEmpty else { return }
        guard let browser = frontmostBrowserName() else { return }
        guard let url = currentURL(for: browser), shouldBlock(url) else { return }

        lastBlockedURL = url
        replaceCurrentURL(for: browser)
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func shouldBlock(_ url: String) -> Bool {
        let lowercasedURL = url.lowercased()
        return blockedSites.contains { lowercasedURL.contains($0) }
    }

    private func frontmostBrowserName() -> String? {
        let script = """
        tell application "System Events"
          set frontApp to name of first application process whose frontmost is true
        end tell
        return frontApp
        """

        guard let appName = runAppleScript(script) else { return nil }
        let supported = ["Safari", "Google Chrome", "Microsoft Edge", "Brave Browser"]
        return supported.first { $0 == appName }
    }

    private func currentURL(for browser: String) -> String? {
        switch browser {
        case "Safari":
            return runAppleScript("""
            tell application "Safari"
              if not (exists front document) then return ""
              return URL of front document
            end tell
            """)
        case "Google Chrome", "Microsoft Edge", "Brave Browser":
            return runAppleScript("""
            tell application "\(browser)"
              if not (exists front window) then return ""
              return URL of active tab of front window
            end tell
            """)
        default:
            return nil
        }
    }

    private func replaceCurrentURL(for browser: String) {
        let blockPage = "about:blank"

        switch browser {
        case "Safari":
            _ = runAppleScript("""
            tell application "Safari"
              if exists front document then set URL of front document to "\(blockPage)"
            end tell
            """)
        case "Google Chrome", "Microsoft Edge", "Brave Browser":
            _ = runAppleScript("""
            tell application "\(browser)"
              if exists front window then set URL of active tab of front window to "\(blockPage)"
            end tell
            """)
        default:
            break
        }
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let output = script.executeAndReturnError(&error)

        if let error {
            authorizationHint = error.description
            return nil
        }

        authorizationHint = nil
        return output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
