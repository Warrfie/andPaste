import AppKit
import SwiftUI

@MainActor
final class ClipboardHistoryPanelController {
    private let panel: BorderlessKeyPanel

    init(
        store: ClipboardStore,
        onClose: @escaping () -> Void,
        onSelect: @escaping (ClipboardItem, PasteMode) -> Void
    ) {
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
        AppLog.write("History panel shown; isVisible=\(panel.isVisible); frame=\(NSStringFromRect(panel.frame)); level=\(panel.level.rawValue)")
    }

    func close() {
        panel.close()
    }
}

private final class BorderlessKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
