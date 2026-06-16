import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    private static let launchAtLoginUserDefaultsKey = "launchAtLogin"
    private static let hotkeyShortcutUserDefaultsKey = "hotkeyShortcut"

    let store = ClipboardStore()
    @Published private(set) var launchAtLogin = UserDefaults.standard.bool(forKey: launchAtLoginUserDefaultsKey)
    @Published private(set) var hotkeyShortcut: HotkeyShortcut

    private let hotkeyManager = HotkeyManager()
    private let pasteController = PasteController()
    private let singleInstanceController = SingleInstanceController()
    private let launchAtLoginController = LaunchAtLoginController()
    private var targetApplication: NSRunningApplication?
    private var didStart = false
    private var isPrimaryInstance = true
    private var settingsWindow: NSWindow?
    private var settingsWindowDelegate: SettingsWindowDelegate?
    private lazy var historyPanelController = ClipboardHistoryPanelController(
        store: store,
        onClose: { [weak self] in
            self?.closeHistoryWindow()
        },
        onSelect: { [weak self] item, mode in
            self?.select(item, mode: mode)
        }
    )

    init() {
        hotkeyShortcut = HotkeyShortcut(
            rawValue: UserDefaults.standard.string(forKey: Self.hotkeyShortcutUserDefaultsKey) ?? ""
        ) ?? .fnV
        hotkeyManager.shortcut = hotkeyShortcut
        AppLog.write("AppModel initialized; shortcut=\(hotkeyShortcut.rawValue)")
        guard !XcodePreviewSupport.isRunning else { return }
        isPrimaryInstance = singleInstanceController.becomePrimary(onShowHistoryRequest: { [weak self] in
            self?.showHistoryWindow()
        })
    }

    func start() {
        AppLog.write("AppModel start requested; didStart=\(didStart); isPrimaryInstance=\(isPrimaryInstance)")
        guard !didStart else { return }
        guard !XcodePreviewSupport.isRunning else {
            AppLog.write("AppModel start skipped in Xcode preview")
            return
        }

        didStart = true
        guard isPrimaryInstance else {
            AppLog.write("Secondary instance detected; terminating")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        store.start()
        AppLog.write("Clipboard store started")
        Task { @MainActor [store] in
            store.preloadPersistedHistory()
        }

        hotkeyManager.onShowHistory = { [weak self] in
            self?.toggleHistoryWindow()
        }
        hotkeyManager.start()
        AppLog.write("Hotkey manager started")
    }

    func showHistoryWindow() {
        AppLog.write("Show history window")
        rememberTargetApplication()
        store.prepareForDisplay()
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
        AppLog.write("Close history window")
        historyPanelController.close()
    }

    func showSettingsWindow() {
        AppLog.write("Show settings window")
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(model: self))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "CopyPaste Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        let delegate = SettingsWindowDelegate { [weak self] in
            self?.settingsWindow = nil
            self?.settingsWindowDelegate = nil
        }
        window.delegate = delegate
        window.center()
        settingsWindow = window
        settingsWindowDelegate = delegate

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
        AppLog.write("Set launch at login: \(isEnabled)")
        launchAtLogin = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.launchAtLoginUserDefaultsKey)
        launchAtLoginController.apply(isEnabled: isEnabled)
    }

    func setHotkeyShortcut(_ shortcut: HotkeyShortcut) {
        AppLog.write("Set hotkey shortcut: \(shortcut.rawValue)")
        hotkeyShortcut = shortcut
        UserDefaults.standard.set(shortcut.rawValue, forKey: Self.hotkeyShortcutUserDefaultsKey)
        hotkeyManager.shortcut = shortcut
    }

    func quit() {
        AppLog.write("Quit requested")
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

private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
