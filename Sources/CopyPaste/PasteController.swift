import AppKit
import ApplicationServices

@MainActor
final class PasteController {
    private static let keyCodeForV: CGKeyCode = 9
    private static let pasteDelay: TimeInterval = 0.16

    func pasteIntoTargetApplication(_ application: NSRunningApplication?) {
        guard ensureAccessibilityPermission() else {
            AppLog.write("Paste skipped: accessibility permission is not granted")
            return
        }
        application?.activate(options: [.activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteDelay) {
            self.postCommandV()
        }
    }

    private func ensureAccessibilityPermission() -> Bool {
        guard !AXIsProcessTrusted() else { return true }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.keyCodeForV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.keyCodeForV, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
