import AppKit
import XCTest
@testable import andPasteCore

@MainActor
final class HistoryWindowSupportTests: XCTestCase {
    func testConstrainedFrameKeepsResizedWindowInsideVisibleFrame() {
        let visibleFrame = NSRect(x: 0, y: 63, width: 1512, height: 881)
        let frameAfterInitialResize = NSRect(x: 626, y: -110, width: 520, height: 592)

        let constrained = HistoryWindowSupport.constrainedFrame(frameAfterInitialResize, inside: visibleFrame)

        XCTAssertEqual(constrained.origin.x, 626)
        XCTAssertEqual(constrained.origin.y, visibleFrame.minY + 12)
        XCTAssertGreaterThanOrEqual(constrained.minY, visibleFrame.minY + 12)
        XCTAssertLessThanOrEqual(constrained.maxY, visibleFrame.maxY - 12)
    }

    func testConstrainedFrameKeepsWindowInsideHorizontalEdges() {
        let visibleFrame = NSRect(x: 100, y: 100, width: 800, height: 600)

        let leftConstrained = HistoryWindowSupport.constrainedFrame(
            NSRect(x: -300, y: 300, width: 520, height: 300),
            inside: visibleFrame
        )
        let rightConstrained = HistoryWindowSupport.constrainedFrame(
            NSRect(x: 700, y: 300, width: 520, height: 300),
            inside: visibleFrame
        )

        XCTAssertEqual(leftConstrained.minX, visibleFrame.minX + 12)
        XCTAssertEqual(rightConstrained.maxX, visibleFrame.maxX - 12)
    }

    func testEventBelongsToHistoryWindowWhenEventWindowMatches() {
        let historyWindow = NSWindow()
        let otherWindow = NSWindow()

        XCTAssertTrue(
            HistoryWindowSupport.eventBelongsToHistoryWindow(
                eventWindow: historyWindow,
                keyWindow: otherWindow,
                historyWindow: historyWindow
            )
        )
    }

    func testEventBelongsToHistoryWindowWhenKeyWindowMatches() {
        let historyWindow = NSWindow()
        let otherWindow = NSWindow()

        XCTAssertTrue(
            HistoryWindowSupport.eventBelongsToHistoryWindow(
                eventWindow: otherWindow,
                keyWindow: historyWindow,
                historyWindow: historyWindow
            )
        )
    }

    func testEventOutsideHistoryWindowDoesNotBelongToHistoryWindow() {
        let historyWindow = NSWindow()
        let eventWindow = NSWindow()
        let keyWindow = NSWindow()

        XCTAssertFalse(
            HistoryWindowSupport.eventBelongsToHistoryWindow(
                eventWindow: eventWindow,
                keyWindow: keyWindow,
                historyWindow: historyWindow
            )
        )
    }
}
