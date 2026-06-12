import AppKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private let maxItems = 60
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        if let item = ClipboardStore.readCurrentItem(from: pasteboard) {
            items = [item]
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func clearHistory() {
        items.removeAll()
    }

    func copyToPasteboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image, _):
            pasteboard.writeObjects([image])
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
        lastChangeCount = pasteboard.changeCount
        add(item)
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let item = Self.readCurrentItem(from: pasteboard) else { return }
        add(item)
    }

    private func add(_ item: ClipboardItem) {
        items.removeAll { $0.fingerprint == item.fingerprint }
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    private static func readCurrentItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            return ClipboardItem(content: .files(urls))
        }

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return ClipboardItem(content: .text(string))
        }

        if let image = NSImage(pasteboard: pasteboard) {
            let data = image.tiffRepresentation ?? Data()
            return ClipboardItem(content: .image(image, data))
        }

        return nil
    }
}
