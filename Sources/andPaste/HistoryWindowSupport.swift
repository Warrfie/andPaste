import AppKit

@MainActor
enum HistoryWindowSupport {
    private static weak var registeredWindow: NSWindow?

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
        frame = constrainedFrame(frame, toVisibleFrameOf: window.screen)
        window.setFrame(frame, display: true)
    }

    static func owns(_ event: NSEvent) -> Bool {
        if eventBelongsToHistoryWindow(
            eventWindow: event.window,
            keyWindow: NSApp.keyWindow,
            historyWindow: historyWindow
        ) {
            return true
        }
        return eventLocationBelongsToHistoryWindow(event, historyWindow: historyWindow)
    }

    static func eventBelongsToHistoryWindow(
        eventWindow: NSWindow?,
        keyWindow: NSWindow?,
        historyWindow: NSWindow?
    ) -> Bool {
        guard let historyWindow else { return false }
        return eventWindow === historyWindow || keyWindow === historyWindow
    }

    static func currentMouseLocationBelongsToHistoryWindow() -> Bool {
        guard let historyWindow else { return false }
        return point(NSEvent.mouseLocation, isInside: historyWindow.frame)
    }

    private static func eventLocationBelongsToHistoryWindow(
        _ event: NSEvent,
        historyWindow: NSWindow?
    ) -> Bool {
        guard let historyWindow, let eventWindow = event.window else { return false }
        let screenPoint = eventWindow.convertPoint(toScreen: event.locationInWindow)
        return point(screenPoint, isInside: historyWindow.frame)
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
        frame = constrainedFrame(frame, inside: visibleFrame)
        window.setFrame(frame, display: true)
        AppLog.write("History panel positioned; mouse=\(NSStringFromPoint(mouseLocation)); visibleFrame=\(NSStringFromRect(visibleFrame)); frame=\(NSStringFromRect(frame))")
    }

    private static func constrainedFrame(_ frame: NSRect, toVisibleFrameOf screen: NSScreen?) -> NSRect {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        guard let visibleFrame else { return frame }
        return constrainedFrame(frame, inside: visibleFrame)
    }

    nonisolated static func constrainedFrame(
        _ frame: NSRect,
        inside visibleFrame: NSRect,
        inset: CGFloat = 12
    ) -> NSRect {
        var constrainedFrame = frame
        constrainedFrame.origin.x = min(
            max(constrainedFrame.origin.x, visibleFrame.minX + inset),
            visibleFrame.maxX - constrainedFrame.width - inset
        )
        constrainedFrame.origin.y = min(
            max(constrainedFrame.origin.y, visibleFrame.minY + inset),
            visibleFrame.maxY - constrainedFrame.height - inset
        )
        return constrainedFrame
    }

    nonisolated static func point(_ point: NSPoint, isInside frame: NSRect) -> Bool {
        frame.contains(point)
    }
}
