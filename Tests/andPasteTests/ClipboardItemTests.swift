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
        let item = ClipboardItem(content: .text("hello", richTextPayloads: [richText]))

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

    @MainActor
    func testPNGDataUsesFallbackImageData() {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        let fallbackData = bitmap?.representation(using: .png, properties: [:]) ?? Data()
        let image = NSImage(data: fallbackData) ?? NSImage(size: NSSize(width: 2, height: 2))

        let pngData = ClipboardStore.pngData(for: image, fallbackData: fallbackData)

        XCTAssertNotNil(pngData)
        XCTAssertTrue(pngData?.starts(with: Data([0x89, 0x50, 0x4E, 0x47])) == true)
    }

    @MainActor
    func testImageExportURLUsesPNGFileName() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let url = ClipboardStore.imageExportURL(in: URL(fileURLWithPath: "/tmp"), date: date)

        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("andPaste Image "))
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

    func testPlainTextRepresentationNormalizesChecklistGlyphs() {
        let item = ClipboardItem(content: .text("☐ не доне\n☑ доне\n  ✔ nested"))

        XCTAssertEqual(item.plainTextRepresentation, "- [ ] не доне\n- [x] доне\n  - [x] nested")
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
    func testStringPasteboardItemKeepsRichTextPayloads() {
        let rtf = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.rtf.rawValue,
            data: Data([4, 5, 6])
        )
        let html = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.html.rawValue,
            data: Data("<b>formatted</b>".utf8)
        )
        let item = ClipboardStore.makeItem(
            fileURLs: nil,
            string: "- [ ] formatted",
            richTextPayloads: [rtf, html],
            image: nil,
            pasteboardTypes: [.rtf, .html, .string]
        )

        guard case .text(let text, let storedRichTextPayloads) = item?.content else {
            XCTFail("Expected text item")
            return
        }
        XCTAssertEqual(text, "- [ ] formatted")
        XCTAssertEqual(storedRichTextPayloads, [rtf, html])
    }

    @MainActor
    func testStringPasteboardItemKeepsSourceRichTextOrder() {
        let html = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.html.rawValue,
            data: Data("<b>formatted</b>".utf8)
        )
        let rtf = ClipboardItem.RichTextPayload(
            pasteboardType: NSPasteboard.PasteboardType.rtf.rawValue,
            data: Data([4, 5, 6])
        )
        let item = ClipboardStore.makeItem(
            fileURLs: nil,
            string: "formatted",
            richTextPayloads: [html, rtf],
            image: nil,
            pasteboardTypes: [.html, .rtf, .string]
        )

        guard case .text(_, let storedRichTextPayloads) = item?.content else {
            XCTFail("Expected text item")
            return
        }
        XCTAssertEqual(storedRichTextPayloads, [html, rtf])
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
