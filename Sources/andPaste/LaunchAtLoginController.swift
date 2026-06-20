import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    func apply(isEnabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp
        do {
            switch (isEnabled, service.status) {
            case (true, .enabled), (false, .notRegistered):
                return
            case (true, _):
                try service.register()
            case (false, _):
                try service.unregister()
            }
        } catch {
            presentFailureAlert(error)
        }
    }

    private func presentFailureAlert(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Unable to update Launch at Login."
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
