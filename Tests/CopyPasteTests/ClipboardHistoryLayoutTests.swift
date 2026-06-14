import AppKit
import XCTest
@testable import CopyPasteCore

final class ClipboardHistoryLayoutTests: XCTestCase {
    func testRowHeightDependsOnContentType() {
        XCTAssertEqual(
            ClipboardHistoryLayout.rowHeight(for: ClipboardItem(content: .text("text"))),
            72
        )
        XCTAssertEqual(
            ClipboardHistoryLayout.rowHeight(for: ClipboardItem(content: .files([URL(fileURLWithPath: "/tmp/a")]))),
            72
        )
        XCTAssertEqual(
            ClipboardHistoryLayout.rowHeight(for: ClipboardItem(content: .image(NSImage(size: NSSize(width: 10, height: 10)), Data()))),
            132
        )
    }

    func testListHeightIsEmptyStateForNoItems() {
        XCTAssertEqual(ClipboardHistoryLayout.listHeight(for: []), 160)
    }

    func testListHeightIsCapped() {
        let items = (0..<20).map { ClipboardItem(content: .text("item \($0)")) }

        XCTAssertEqual(ClipboardHistoryLayout.listHeight(for: items), 320)
    }

    func testContentHeightIncludesHeaderAndSelectedDetailThenCaps() {
        let oneTextItem = [ClipboardItem(content: .text("item"))]

        XCTAssertEqual(
            ClipboardHistoryLayout.contentHeight(filteredItems: oneTextItem, hasSelection: false),
            124
        )
        XCTAssertEqual(
            ClipboardHistoryLayout.contentHeight(filteredItems: oneTextItem, hasSelection: true),
            344
        )

        let manyItems = (0..<20).map { ClipboardItem(content: .text("item \($0)")) }
        XCTAssertEqual(
            ClipboardHistoryLayout.contentHeight(filteredItems: manyItems, hasSelection: true),
            592
        )
    }
}
