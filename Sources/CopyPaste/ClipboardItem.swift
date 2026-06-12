import AppKit
import Foundation

struct ClipboardItem: Identifiable, Equatable {
    enum Content: Equatable {
        case text(String)
        case image(NSImage, Data)
        case files([URL])
    }

    let id = UUID()
    let content: Content
    let createdAt = Date()

    var title: String {
        switch content {
        case .text:
            return "Text"
        case .image:
            return "Image"
        case .files(let urls):
            return urls.count == 1 ? "File" : "\(urls.count) Files"
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

    var fingerprint: String {
        switch content {
        case .text(let text):
            return "text:\(text)"
        case .image(_, let data):
            return "image:\(data.hashValue)"
        case .files(let urls):
            return "files:\(urls.map(\.absoluteString).joined(separator: "|"))"
        }
    }
}

private extension String {
    var collapsedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
