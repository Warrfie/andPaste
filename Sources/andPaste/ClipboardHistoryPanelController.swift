import AppKit
import SwiftUI

@MainActor
final class ClipboardHistoryPanelController {
    private let panel: BorderlessKeyPanel
    private let onClose: () -> Void
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    init(
        store: ClipboardStore,
        onClose: @escaping () -> Void,
        onSelect: @escaping (ClipboardItem, PasteMode) -> Void
    ) {
        self.onClose = onClose
        panel = BorderlessKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 52),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "andPaste"
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.minSize = NSSize(width: 420, height: 52)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let rootView = ClipboardHistoryView(
            store: store,
            onClose: onClose,
            onSelect: onSelect
        )
        panel.contentView = NSHostingView(rootView: rootView)
        HistoryWindowSupport.register(panel)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func showNearMouse() {
        HistoryWindowSupport.register(panel)
        HistoryWindowSupport.positionNearMouse(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installClickOutsideMonitors()
        AppLog.write("History panel shown; isVisible=\(panel.isVisible); frame=\(NSStringFromRect(panel.frame)); level=\(panel.level.rawValue)")
    }

    func close() {
        removeClickOutsideMonitors()
        panel.close()
    }

    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if self.panel.isVisible, !HistoryWindowSupport.owns(event) {
                self.onClose()
            }
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                self.onClose()
            }
        }
    }

    private func removeClickOutsideMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }
}

private final class BorderlessKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
