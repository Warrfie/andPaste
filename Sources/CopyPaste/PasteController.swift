import AppKit
import ApplicationServices

@MainActor
final class PasteController {
    private static let keyCodeForV: CGKeyCode = 9
    private static let pasteDelay: TimeInterval = 0.16
    private static let accessibilityPromptMarkerFileName = "accessibility-prompt-requested"
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

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

        if !hasRequestedAccessibilityPrompt {
            markAccessibilityPromptRequested()
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }

        presentAccessibilitySettingsAlert()
        return false
    }

    private func presentAccessibilitySettingsAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Accessibility access is required."
        alert.informativeText = "CopyPaste needs Accessibility access to paste selected clipboard items into the active app. Open System Settings and enable CopyPaste."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn,
              let settingsURL = Self.accessibilitySettingsURL else {
            return
        }
        NSWorkspace.shared.open(settingsURL)
    }

    private var hasRequestedAccessibilityPrompt: Bool {
        FileManager.default.fileExists(atPath: Self.accessibilityPromptMarkerURL.path)
    }

    private func markAccessibilityPromptRequested() {
        do {
            let markerURL = Self.accessibilityPromptMarkerURL
            try FileManager.default.createDirectory(
                at: markerURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data().write(to: markerURL, options: .atomic)
        } catch {
            AppLog.write("Unable to persist accessibility prompt marker: \(error.localizedDescription)")
        }
    }

    private static var accessibilityPromptMarkerURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("CopyPaste", isDirectory: true)
            .appendingPathComponent(accessibilityPromptMarkerFileName)
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
