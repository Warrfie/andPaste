import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    let store = ClipboardStore()

    private let hotkeyManager = HotkeyManager()
    private let pasteController = PasteController()
    private let singleInstanceController = SingleInstanceController()
    private var targetApplication: NSRunningApplication?
    private var didStart = false
    private lazy var historyPanelController = ClipboardHistoryPanelController(
        store: store,
        onClose: { [weak self] in
            self?.closeHistoryWindow()
        },
        onSelect: { [weak self] item in
            self?.select(item)
        }
    )

    func start() {
        guard !didStart else { return }

        didStart = true
        guard singleInstanceController.becomePrimary(onShowHistoryRequest: { [weak self] in
            self?.showHistoryWindow()
        }) else {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        store.start()

        hotkeyManager.onShowHistory = { [weak self] in
            self?.toggleHistoryWindow()
        }
        hotkeyManager.start()
    }

    func showHistoryWindow() {
        rememberTargetApplication()
        historyPanelController.showNearMouse()
    }

    func toggleHistoryWindow() {
        if historyPanelController.isVisible {
            closeHistoryWindow()
        } else {
            showHistoryWindow()
        }
    }

    func closeHistoryWindow() {
        historyPanelController.close()
    }

    func select(_ item: ClipboardItem) {
        let application = targetApplication
        store.copyToPasteboard(item)
        closeHistoryWindow()
        pasteController.pasteIntoTargetApplication(application)
    }

    func quit() {
        hotkeyManager.stop()
        store.stop()
        singleInstanceController.stop()
        NSApp.terminate(nil)
    }

    private func rememberTargetApplication() {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        if frontmostApplication?.processIdentifier == NSRunningApplication.current.processIdentifier {
            return
        }
        targetApplication = frontmostApplication
    }
}
