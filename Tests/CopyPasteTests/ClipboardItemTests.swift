import AppKit
import XCTest
@testable import CopyPaste

final class ClipboardItemTests: XCTestCase {
    func testTextSubtitleCollapsesWhitespace() {
        let item = ClipboardItem(content: .text("  hello\n\nworld\tfrom   clipboard  "))

        XCTAssertEqual(item.title, "Text")
        XCTAssertEqual(item.subtitle, "hello world from clipboard")
        XCTAssertEqual(item.searchText, "Text hello world from clipboard")
        XCTAssertEqual(item.fingerprint, "text:  hello\n\nworld\tfrom   clipboard  ")
    }

    func testFileTitleAndSubtitleUseFileNames() {
        let item = ClipboardItem(content: .files([
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.pdf")
        ]))

        XCTAssertEqual(item.title, "2 Files")
        XCTAssertEqual(item.subtitle, "one.txt, two.pdf")
        XCTAssertEqual(item.searchText, "2 Files one.txt, two.pdf")
        XCTAssertEqual(item.fingerprint, "files:file:///tmp/one.txt|file:///tmp/two.pdf")
    }

    func testImageSubtitleUsesImageSize() {
        let image = NSImage(size: NSSize(width: 80, height: 40))
        let item = ClipboardItem(content: .image(image, Data([1, 2, 3])))

        XCTAssertEqual(item.title, "Image")
        XCTAssertEqual(item.subtitle, "80 x 40 px")
        XCTAssertEqual(item.searchText, "Image 80 x 40 px")
        XCTAssertTrue(item.fingerprint.hasPrefix("image:"))
    }
}
