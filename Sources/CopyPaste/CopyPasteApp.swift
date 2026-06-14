import AppKit
import Combine
import SwiftUI

enum XcodePreviewSupport {
    static let isRunning = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

enum AppLog {
    private static let lock = NSLock()

    static var fileURL: URL {
        let baseURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("CopyPaste", isDirectory: true)
            .appendingPathComponent("CopyPaste.log")
    }

    static func write(_ message: String) {
        lock.lock()
        defer { lock.unlock() }

        let formatter = ISO8601DateFormatter()
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            NSLog("CopyPaste log write failed: %@", error.localizedDescription)
        }
    }
}

final class CopyPasteApplicationDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLog.write("Application did finish launching; pid=\(ProcessInfo.processInfo.processIdentifier)")
        NSApp.setActivationPolicy(.accessory)

        let model = AppModel()
        self.model = model
        statusItemController = StatusItemController(model: model)
        model.start()
        AppLog.write("Application launch flow completed")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        AppLog.write("Last window closed; keeping application alive")
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.write("Application will terminate")
    }
}

@MainActor
private final class StatusItemController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellable: AnyCancellable?
    private var aboutWindow: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
        configureButton()
        configureMenu()
        cancellable = model.$hotkeyShortcut.sink { [weak self] shortcut in
            self?.updateButton(for: shortcut)
        }
        AppLog.write("Status item controller installed")
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "CopyPaste")
        button.imagePosition = .imageLeft
        button.font = .systemFont(ofSize: 11, weight: .semibold)
        updateButton(for: model.hotkeyShortcut)
    }

    private func updateButton(for shortcut: HotkeyShortcut) {
        guard let button = statusItem.button else { return }
        switch shortcut {
        case .fnV:
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "CopyPaste")
            button.title = "+ V"
        case .controlOptionV:
            button.image = nil
            button.title = "⌃⌥ V"
        case .commandShiftV:
            button.image = nil
            button.title = "⌘⇧ V"
        }
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(menuItem("Show Clipboard History", action: #selector(showHistory), symbolName: "clipboard"))
        menu.addItem(menuItem("Clear History", action: #selector(clearHistory), symbolName: "trash"))
        menu.addItem(menuItem("Settings", action: #selector(showSettings), symbolName: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(menuItem("About CopyPaste", action: #selector(showAbout), symbolName: "info.circle"))
        menu.addItem(.separator())
        let quitItem = menuItem("Quit CopyPaste", action: #selector(quit), symbolName: "power")
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = [.command]
        menu.addItem(quitItem)
        statusItem.menu = menu
        AppLog.write("Status menu configured")
    }

    private func menuItem(_ title: String, action: Selector, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        return item
    }

    @objc private func showHistory() {
        AppLog.write("Menu action: show history")
        model.showHistoryWindow()
    }

    @objc private func clearHistory() {
        AppLog.write("Menu action: clear history")
        model.store.clearHistory()
    }

    @objc private func showSettings() {
        AppLog.write("Menu action: show settings")
        model.showSettingsWindow()
    }

    @objc private func showAbout() {
        AppLog.write("Menu action: show about")
        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: AboutSceneView(versionTitle: CopyPasteVersion.current.title)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "About CopyPaste"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        aboutWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        model.quit()
    }
}

private struct CopyPasteVersion {
    static var current: CopyPasteVersion {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return CopyPasteVersion(shortVersion: shortVersion, buildVersion: buildVersion)
    }

    let shortVersion: String
    let buildVersion: String

    var title: String {
        "Version \(shortVersion) (\(buildVersion))"
    }
}

private struct AboutSceneView: View {
    let versionTitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: appIconImage)
                .resizable()
                .frame(width: 56, height: 56)

            VStack(spacing: 6) {
                Text("CopyPaste")
                    .font(.title2.weight(.semibold))
                Text(versionTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Fast clipboard history for macOS.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Link("Privacy Policy", destination: URL(string: "https://github.com/Warrfie/CopyPaste/blob/main/docs/PRIVACY.md")!)
                Link("GitHub", destination: URL(string: "https://github.com/Warrfie/CopyPaste")!)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(AboutWindowConfigurator())
    }

    private var appIconImage: NSImage {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            return iconImage
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}

private struct AboutWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

#if DEBUG
struct AboutSceneView_Previews: PreviewProvider {
    static var previews: some View {
        AboutSceneView(versionTitle: "Version 0.1.0 (1)")
    }
}
#endif
