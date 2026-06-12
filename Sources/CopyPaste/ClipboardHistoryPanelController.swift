import AppKit
import SwiftUI

@MainActor
final class ClipboardHistoryPanelController {
    private let panel: BorderlessKeyPanel

    init(
        store: ClipboardStore,
        onClose: @escaping () -> Void,
        onSelect: @escaping (ClipboardItem) -> Void
    ) {
        panel = BorderlessKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 52),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.title = "CopyPaste"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 420, height: 52)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

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
    }

    func close() {
        panel.close()
    }
}

private final class BorderlessKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
