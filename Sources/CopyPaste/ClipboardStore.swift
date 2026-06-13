import AppKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private let maxRecentItems = 50
    private let persistenceURL: URL
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        persistenceURL = Self.defaultPersistenceURL()
        items = Self.loadItems(from: persistenceURL)
        if let item = ClipboardStore.readCurrentItem(from: pasteboard), !items.contains(where: { $0.fingerprint == item.fingerprint }) {
            add(item)
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
        items.removeAll { !$0.isPinned }
        saveItems()
    }

    func copyToPasteboard(_ item: ClipboardItem, asPlainText: Bool = false) {
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image, _):
            if asPlainText {
                pasteboard.setString(item.subtitle, forType: .string)
            } else {
                pasteboard.writeObjects([image])
            }
        case .files(let urls):
            if asPlainText {
                pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
            } else {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        lastChangeCount = pasteboard.changeCount
        add(item)
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        trimItems()
        saveItems()
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let item = Self.readCurrentItem(from: pasteboard) else { return }
        add(item)
    }

    private func add(_ item: ClipboardItem) {
        let existingPinnedState = items.first(where: { $0.fingerprint == item.fingerprint })?.isPinned ?? item.isPinned
        var itemToInsert = item
        itemToInsert.isPinned = existingPinnedState
        items.removeAll { $0.fingerprint == item.fingerprint }
        items.insert(itemToInsert, at: 0)
        sortItems()
        trimItems()
        saveItems()
    }

    private func sortItems() {
        items.sort {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func trimItems() {
        let pinned = items.filter(\.isPinned)
        let recent = items.filter { !$0.isPinned }.prefix(maxRecentItems)
        items = pinned + recent
    }

    private func saveItems() {
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let records = items.compactMap(PersistentClipboardItem.init(item:))
            let data = try JSONEncoder().encode(records)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            assertionFailure("Unable to save clipboard history: \(error.localizedDescription)")
        }
    }

    private static func loadItems(from url: URL) -> [ClipboardItem] {
        do {
            let data = try Data(contentsOf: url)
            let records = try JSONDecoder().decode([PersistentClipboardItem].self, from: data)
            return records.compactMap(\.item)
        } catch {
            return []
        }
    }

    private static func defaultPersistenceURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("CopyPaste", isDirectory: true)
            .appendingPathComponent("history.json")
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

private struct PersistentClipboardItem: Codable {
    enum ContentKind: String, Codable {
        case text
        case image
        case files
    }

    let id: UUID
    let createdAt: Date
    let isPinned: Bool
    let kind: ContentKind
    let text: String?
    let imageData: Data?
    let fileURLs: [URL]?

    init?(item: ClipboardItem) {
        id = item.id
        createdAt = item.createdAt
        isPinned = item.isPinned
        switch item.content {
        case .text(let value):
            kind = .text
            text = value
            imageData = nil
            fileURLs = nil
        case .image(_, let data):
            kind = .image
            text = nil
            imageData = data
            fileURLs = nil
        case .files(let urls):
            kind = .files
            text = nil
            imageData = nil
            fileURLs = urls
        }
    }

    var item: ClipboardItem? {
        switch kind {
        case .text:
            guard let text else { return nil }
            return ClipboardItem(id: id, content: .text(text), createdAt: createdAt, isPinned: isPinned)
        case .image:
            guard let imageData, let image = NSImage(data: imageData) else { return nil }
            return ClipboardItem(id: id, content: .image(image, imageData), createdAt: createdAt, isPinned: isPinned)
        case .files:
            guard let fileURLs else { return nil }
            return ClipboardItem(id: id, content: .files(fileURLs), createdAt: createdAt, isPinned: isPinned)
        }
    }
}
