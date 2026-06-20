import AppKit
import CryptoKit
import Foundation

struct ClipboardItem: Identifiable, Equatable {
    enum ContentType: String {
        case text
        case image
        case files

        var title: String {
            switch self {
            case .text:
                return "Text"
            case .image:
                return "Image"
            case .files:
                return "File"
            }
        }
    }

    enum DisplayType: Equatable {
        case text
        case image
        case file
        case files
        case webLink
        case fileLink

        var title: String {
            switch self {
            case .text:
                return "Text"
            case .image:
                return "Image"
            case .file:
                return "File"
            case .files:
                return "Files"
            case .webLink:
                return "Link"
            case .fileLink:
                return "File Link"
            }
        }

        var systemImageName: String {
            switch self {
            case .text:
                return "text.alignleft"
            case .image:
                return "photo"
            case .file:
                return "doc"
            case .files:
                return "folder"
            case .webLink:
                return "link"
            case .fileLink:
                return "doc"
            }
        }
    }

    enum Content: Equatable {
        case text(String)
        case image(NSImage, Data)
        case files([URL])
    }

    let id: UUID
    let content: Content
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), content: Content, createdAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    var contentType: ContentType {
        switch content {
        case .text:
            return .text
        case .image:
            return .image
        case .files:
            return .files
        }
    }

    var displayType: DisplayType {
        switch content {
        case .text(let text):
            return Self.displayType(forText: text)
        case .image:
            return .image
        case .files(let urls):
            return urls.count == 1 ? .file : .files
        }
    }

    var title: String {
        switch content {
        case .text, .image:
            return contentType.title
        case .files(let urls):
            return urls.count == 1 ? contentType.title : "\(urls.count) Files"
        }
    }

    var subtitle: String {
        switch content {
        case .text(let text):
            return text.collapsedWhitespace
        case .image(let image, _):
            return "\(Int(image.size.width)) x \(Int(image.size.height)) px"
        case .files(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    var searchText: String {
        "\(title) \(subtitle)"
    }

    var supportsPlainTextPaste: Bool {
        if case .text = content {
            return true
        }
        return false
    }

    var fingerprint: String {
        switch content {
        case .text(let text):
            return "text:\(text)"
        case .image(_, let data):
            return "image:\(Self.sha256Hex(for: data))"
        case .files(let urls):
            return "files:\(urls.map(\.absoluteString).joined(separator: "|"))"
        }
    }

    private static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func displayType(forText text: String) -> DisplayType {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return .text }

        if let url = URL(string: trimmedText), let scheme = url.scheme?.lowercased() {
            if url.isFileURL {
                return .fileLink
            }
            if scheme == "http" || scheme == "https" {
                return .webLink
            }
        }

        var isDirectory: ObjCBool = false
        if trimmedText.hasPrefix("/"),
           FileManager.default.fileExists(atPath: trimmedText, isDirectory: &isDirectory) {
            return .fileLink
        }

        return .text
    }
}

private extension String {
    var collapsedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
