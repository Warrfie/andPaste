import AppKit
import XCTest
@testable import andPasteCore

final class ClipboardItemTests: XCTestCase {
    func testTextSubtitleCollapsesWhitespace() {
        let item = ClipboardItem(content: .text("  hello\n\nworld\tfrom   clipboard  "))

        XCTAssertEqual(item.contentType, .text)
        XCTAssertEqual(item.displayType, .text)
        XCTAssertEqual(item.title, "Text")
        XCTAssertEqual(item.subtitle, "hello world from clipboard")
        XCTAssertEqual(item.searchText, "Text hello world from clipboard")
        XCTAssertEqual(item.fingerprint, "text:  hello\n\nworld\tfrom   clipboard  ")
    }

    func testRichTextPayloadKeepsPlainTextPreviewAndAffectsFingerprint() {
        let richText = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.rtf.rawValue,
            data: Data([1, 2, 3])
        )
        let item = ClipboardItem(content: .text("hello", richText: richText))

        XCTAssertEqual(item.contentType, .text)
        XCTAssertEqual(item.displayType, .text)
        XCTAssertEqual(item.subtitle, "hello")
        XCTAssertEqual(item.plainTextRepresentation, "hello")
        XCTAssertTrue(item.fingerprint.hasPrefix("text:hello:rich:"))
    }

    func testFileTitleAndSubtitleUseFileNames() {
        let item = ClipboardItem(content: .files([
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.pdf")
        ]))

        XCTAssertEqual(item.contentType, .files)
        XCTAssertEqual(item.displayType, .files)
        XCTAssertEqual(item.title, "2 Files")
        XCTAssertEqual(item.subtitle, "one.txt, two.pdf")
        XCTAssertEqual(item.searchText, "2 Files one.txt, two.pdf")
        XCTAssertEqual(item.fingerprint, "files:file:///tmp/one.txt|file:///tmp/two.pdf")
    }

    func testImageSubtitleUsesImageSize() {
        let image = NSImage(size: NSSize(width: 80, height: 40))
        let item = ClipboardItem(content: .image(image, Data([1, 2, 3])))

        XCTAssertEqual(item.contentType, .image)
        XCTAssertEqual(item.displayType, .image)
        XCTAssertEqual(item.title, "Image")
        XCTAssertEqual(item.subtitle, "80 x 40 px")
        XCTAssertEqual(item.searchText, "Image 80 x 40 px")
        XCTAssertEqual(item.fingerprint, "image:039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81")
    }

    func testAllContentTypesSupportPlainTextPaste() {
        let textItem = ClipboardItem(content: .text("hello"))
        let image = NSImage(size: NSSize(width: 2, height: 2))
        let imageItem = ClipboardItem(content: .image(image, Data([1, 2, 3])))
        let fileItem = ClipboardItem(content: .files([URL(fileURLWithPath: "/tmp/example.txt")]))

        XCTAssertTrue(textItem.supportsPlainTextPaste)
        XCTAssertTrue(imageItem.supportsPlainTextPaste)
        XCTAssertTrue(fileItem.supportsPlainTextPaste)
    }

    func testPlainTextRepresentationUsesPasteSafeTextOnly() {
        let image = NSImage(size: NSSize(width: 80, height: 40))
        let fileItem = ClipboardItem(content: .files([
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.pdf")
        ]))

        XCTAssertEqual(ClipboardItem(content: .text("hello")).plainTextRepresentation, "hello")
        XCTAssertEqual(ClipboardItem(content: .image(image, Data())).plainTextRepresentation, "80 x 40 px")
        XCTAssertEqual(fileItem.plainTextRepresentation, "/tmp/one.txt\n/tmp/two.pdf")
    }

    @MainActor
    func testLeadingSlashStringClassifiesAsTextWhenPasteboardTypeIsString() {
        let item = ClipboardStore.makeItem(
            fileURLs: [URL(fileURLWithPath: "/ZSQ-example")],
            string: "/ZSQ-example",
            image: nil,
            pasteboardTypes: [.string]
        )

        XCTAssertEqual(item?.contentType, .text)
        XCTAssertEqual(item?.subtitle, "/ZSQ-example")
    }

    @MainActor
    func testStringPasteboardItemKeepsRichTextPayload() {
        let richText = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.rtf.rawValue,
            data: Data([4, 5, 6])
        )
        let item = ClipboardStore.makeItem(
            fileURLs: nil,
            string: "- [ ] formatted",
            richText: richText,
            image: nil,
            pasteboardTypes: [.rtf, .string]
        )

        guard case .text(let text, let storedRichText) = item?.content else {
            XCTFail("Expected text item")
            return
        }
        XCTAssertEqual(text, "- [ ] formatted")
        XCTAssertEqual(storedRichText, richText)
    }

    @MainActor
    func testFileURLPasteboardTypeClassifiesAsFiles() {
        let item = ClipboardStore.makeItem(
            fileURLs: [URL(fileURLWithPath: "/tmp/example.txt")],
            string: "/tmp/example.txt",
            image: nil,
            pasteboardTypes: [.fileURL, .string]
        )

        XCTAssertEqual(item?.contentType, .files)
        XCTAssertEqual(item?.subtitle, "example.txt")
    }

    func testTextDisplayTypeDetectsLinksWithoutTreatingUnknownSlashTextAsFile() {
        XCTAssertEqual(ClipboardItem(content: .text("https://example.com")).displayType, .webLink)
        XCTAssertEqual(ClipboardItem(content: .text("file:///tmp/example.txt")).displayType, .fileLink)
        XCTAssertEqual(ClipboardItem(content: .text("/ZSQ-example")).displayType, .text)
    }

    func testSingleFileDisplayType() {
        let item = ClipboardItem(content: .files([URL(fileURLWithPath: "/tmp/example.txt")]))

        XCTAssertEqual(item.displayType, .file)
    }
}
