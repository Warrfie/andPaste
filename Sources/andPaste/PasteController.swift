import AppKit
import ApplicationServices

@MainActor
final class PasteController {
    private static let keyCodeForV: CGKeyCode = 9
    private static let pasteDelay: TimeInterval = 0.35

    private var didRequestAccessibilityPromptThisLaunch = false

    func pasteIntoTargetApplication(_ application: NSRunningApplication?) {
        guard ensureAccessibilityPermission() else {
            AppLog.write("Paste skipped: accessibility permission is not granted")
            return
        }

        AppLog.write("Paste requested; target=\(Self.describe(application)); frontmost=\(Self.describe(NSWorkspace.shared.frontmostApplication))")
        application?.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteDelay) {
            AppLog.write("Posting paste shortcut; frontmost=\(Self.describe(NSWorkspace.shared.frontmostApplication))")
            self.postCommandV()
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        guard !CGPreflightPostEventAccess() else { return true }

        if !didRequestAccessibilityPromptThisLaunch {
            didRequestAccessibilityPromptThisLaunch = true
            return requestPostEventAccess()
        }

        AppLog.write("Paste skipped: post event access is not granted")
        return false
    }

    private func requestPostEventAccess() -> Bool {
        let isTrusted = CGRequestPostEventAccess()
        AppLog.write(
            "Post event access requested; trusted=\(isTrusted); axTrusted=\(AXIsProcessTrusted()); bundleID=\(Bundle.main.bundleIdentifier ?? "unknown"); bundlePath=\(Bundle.main.bundlePath)"
        )
        return isTrusted
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.keyCodeForV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.keyCodeForV, keyDown: false) else {
            AppLog.write("Paste shortcut skipped: unable to create keyboard events")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        AppLog.write("Paste shortcut posted")
    }

    private static func describe(_ application: NSRunningApplication?) -> String {
        guard let application else { return "nil" }
        return "\(application.localizedName ?? "unknown") pid=\(application.processIdentifier) bundleID=\(application.bundleIdentifier ?? "unknown")"
    }
}
