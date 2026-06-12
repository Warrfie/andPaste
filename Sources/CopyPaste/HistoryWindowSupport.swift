import AppKit

@MainActor
enum HistoryWindowSupport {
    private static weak var registeredWindow: NSWindow?

    static var isHistoryWindowVisible: Bool {
        historyWindow?.isVisible == true
    }

    static func register(_ window: NSWindow) {
        registeredWindow = window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true
    }

    static func resizeHistoryWindow(width: CGFloat, height: CGFloat) {
        guard let window = historyWindow else { return }
        let oldFrame = window.frame
        window.setContentSize(NSSize(width: width, height: height))
        var frame = window.frame
        frame.origin.x = oldFrame.midX - frame.width / 2
        frame.origin.y = oldFrame.maxY - frame.height
        window.setFrame(frame, display: true)
    }

    static func closeHistoryWindow() {
        historyWindow?.close()
    }

    private static var historyWindow: NSWindow? {
        registeredWindow
    }

    static func positionNearMouse(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let anchor = NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1)
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchor) }) ?? NSScreen.main else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = min(max(anchor.midX - frame.width / 2, visibleFrame.minX + 12), visibleFrame.maxX - frame.width - 12)
        frame.origin.y = min(max(anchor.minY - frame.height - 10, visibleFrame.minY + 12), visibleFrame.maxY - frame.height - 12)
        window.setFrame(frame, display: true)
    }
}
