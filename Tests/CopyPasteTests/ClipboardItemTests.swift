import AppKit
import XCTest
@testable import CopyPasteCore

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
        XCTAssertEqual(item.fingerprint, "image:039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81")
    }

    func testOnlyTextSupportsPlainTextPaste() {
        let textItem = ClipboardItem(content: .text("hello"))
        let image = NSImage(size: NSSize(width: 2, height: 2))
        let imageItem = ClipboardItem(content: .image(image, Data([1, 2, 3])))
        let fileItem = ClipboardItem(content: .files([URL(fileURLWithPath: "/tmp/example.txt")]))

        XCTAssertTrue(textItem.supportsPlainTextPaste)
        XCTAssertFalse(imageItem.supportsPlainTextPaste)
        XCTAssertFalse(fileItem.supportsPlainTextPaste)
    }
}
