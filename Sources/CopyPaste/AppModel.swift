import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    private static let launchAtLoginUserDefaultsKey = "launchAtLogin"

    let store = ClipboardStore()
    @Published private(set) var launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginUserDefaultsKey)

    private let hotkeyManager = HotkeyManager()
    private let pasteController = PasteController()
    private let singleInstanceController = SingleInstanceController()
    private let launchAtLoginController = LaunchAtLoginController()
    private var targetApplication: NSRunningApplication?
    private var didStart = false
    private lazy var historyPanelController = ClipboardHistoryPanelController(
        store: store,
        onClose: { [weak self] in
            self?.closeHistoryWindow()
        },
        onSelect: { [weak self] item, mode in
            self?.select(item, mode: mode)
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
        launchAtLoginController.apply(isEnabled: launchAtLogin)
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

    func select(_ item: ClipboardItem, mode: PasteMode = .plainText) {
        let application = targetApplication
        switch mode {
        case .plainText:
            store.copyToPasteboard(item, asPlainText: true)
        }
        closeHistoryWindow()
        pasteController.pasteIntoTargetApplication(application)
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLogin = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.launchAtLoginUserDefaultsKey)
        launchAtLoginController.apply(isEnabled: isEnabled)
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
