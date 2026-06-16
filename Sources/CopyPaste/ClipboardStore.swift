import AppKit
import CryptoKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private let maxRecentItems = 50
    private static let filePasteboardTypes: Set<NSPasteboard.PasteboardType> = [
        .fileURL,
        NSPasteboard.PasteboardType("NSFilenamesPboardType")
    ]
    private static let imagePasteboardTypes: Set<NSPasteboard.PasteboardType> = [
        .tiff,
        .png,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic")
    ]
    private static let stringPasteboardTypes: Set<NSPasteboard.PasteboardType> = [
        .string,
        NSPasteboard.PasteboardType("NSStringPboardType"),
        NSPasteboard.PasteboardType("TEXT"),
        NSPasteboard.PasteboardType("UTF8_STRING")
    ]
    private static let saveCoalescingDelay: TimeInterval = 0.25
    private let persistenceURL: URL
    private let saveQueue = DispatchQueue(label: "com.warrfie.copypaste.history-save", qos: .utility)
    private var encryptionKey: SymmetricKey?
    private var didLoadPersistedItems = false
    private var lastChangeCount: Int
    private var timer: Timer?
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var pendingSaveSnapshot: ClipboardHistorySaveSnapshot?

    init() {
        lastChangeCount = pasteboard.changeCount
        persistenceURL = Self.defaultPersistenceURL()
    }

    func start() {
        guard timer == nil else { return }
        AppLog.write("ClipboardStore start")
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
    }

    func preloadPersistedHistory() {
        let startedAt = Date()
        loadPersistedHistoryIfNeeded()
        AppLog.write(
            "Clipboard history preload completed; itemCount=\(items.count); duration=\(String(format: "%.3f", Date().timeIntervalSince(startedAt)))s"
        )
    }

    func stop() {
        AppLog.write("ClipboardStore stop")
        timer?.invalidate()
        timer = nil
        flushPendingSave()
    }

    func clearHistory() {
        loadPersistedHistoryIfNeeded()
        items.removeAll { !$0.isPinned }
        saveItems()
    }

    func copyToPasteboard(_ item: ClipboardItem, asPlainText: Bool = false) {
        let shouldPasteAsPlainText = asPlainText && item.supportsPlainTextPaste
        pasteboard.clearContents()
        switch item.content {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let image, _):
            if shouldPasteAsPlainText {
                pasteboard.setString(item.subtitle, forType: .string)
            } else {
                pasteboard.writeObjects([image])
            }
        case .files(let urls):
            if shouldPasteAsPlainText {
                pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
            } else {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ item: ClipboardItem) {
        loadPersistedHistoryIfNeeded()
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        trimItems()
        saveItems()
    }

    func prepareForDisplay() {
        loadPersistedHistoryIfNeeded()
        if let item = ClipboardStore.readCurrentItem(from: pasteboard), !items.contains(where: { $0.fingerprint == item.fingerprint }) {
            add(item)
        }
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let item = Self.readCurrentItem(from: pasteboard) else { return }
        loadPersistedHistoryIfNeeded()
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
        guard let encryptionKey = loadEncryptionKeyIfNeeded() else {
            assertionFailure("Unable to save clipboard history: encryption key is unavailable")
            return
        }

        let snapshot = ClipboardHistorySaveSnapshot(
            records: items.compactMap(PersistentClipboardItem.init(item:)),
            persistenceURL: persistenceURL,
            encryptionKey: encryptionKey
        )
        pendingSaveSnapshot = snapshot
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            Self.writeSaveSnapshot(snapshot)
        }
        pendingSaveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + Self.saveCoalescingDelay, execute: workItem)
    }

    private func flushPendingSave() {
        guard let snapshot = pendingSaveSnapshot else { return }
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        pendingSaveSnapshot = nil
        saveQueue.sync {
            Self.writeSaveSnapshot(snapshot)
        }
    }

    private static func writeSaveSnapshot(_ snapshot: ClipboardHistorySaveSnapshot) {
        let startedAt = Date()
        do {
            try FileManager.default.createDirectory(
                at: snapshot.persistenceURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let plainData = try JSONEncoder().encode(snapshot.records)
            let encryptedData = try ClipboardHistoryEncryption.encrypt(plainData, using: snapshot.encryptionKey)
            try encryptedData.write(to: snapshot.persistenceURL, options: .atomic)
            AppLog.write(
                "Clipboard history save completed; itemCount=\(snapshot.records.count); plainBytes=\(plainData.count); encryptedBytes=\(encryptedData.count); duration=\(String(format: "%.3f", Date().timeIntervalSince(startedAt)))s"
            )
        } catch {
            AppLog.write("Unable to save clipboard history: \(error.localizedDescription)")
            assertionFailure("Unable to save clipboard history: \(error.localizedDescription)")
        }
    }

    private func loadPersistedHistoryIfNeeded() {
        guard !didLoadPersistedItems else { return }
        didLoadPersistedItems = true
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        items = Self.loadItems(from: persistenceURL, encryptionKey: loadEncryptionKeyIfNeeded())
    }

    private func loadEncryptionKeyIfNeeded() -> SymmetricKey? {
        if let encryptionKey {
            return encryptionKey
        }
        AppLog.write("Loading clipboard history encryption key")
        encryptionKey = try? ClipboardHistoryKeychain.loadOrCreateKey()
        if encryptionKey == nil {
            AppLog.write("Clipboard history encryption key is unavailable")
        }
        return encryptionKey
    }

    private static func loadItems(from url: URL, encryptionKey: SymmetricKey?) -> [ClipboardItem] {
        guard let encryptionKey else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let plainData = try ClipboardHistoryEncryption.decrypt(data, using: encryptionKey)
            let records = try JSONDecoder().decode([PersistentClipboardItem].self, from: plainData)
            return records.compactMap(\.item)
        } catch {
            return []
        }
    }

    private static func defaultPersistenceURL() -> URL {
        applicationSupportURL()
            .appendingPathComponent("history.cphistory")
    }

    private static func applicationSupportURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("CopyPaste", isDirectory: true)
    }

    static func readCurrentItem(from pasteboard: NSPasteboard) -> ClipboardItem? {
        let pasteboardTypes = pasteboard.types ?? []
        let fileURLs = hasFileURLs(in: pasteboardTypes)
            ? pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
            : nil
        let image = hasImage(in: pasteboardTypes)
            ? NSImage(pasteboard: pasteboard)
            : nil
        let string = hasString(in: pasteboardTypes)
            ? pasteboard.string(forType: .string)
            : nil

        return makeItem(
            fileURLs: fileURLs,
            string: string,
            image: image,
            pasteboardTypes: pasteboardTypes
        )
    }

    static func makeItem(
        fileURLs: [URL]?,
        string: String?,
        image: NSImage?,
        pasteboardTypes: [NSPasteboard.PasteboardType]
    ) -> ClipboardItem? {
        if hasFileURLs(in: pasteboardTypes),
           let urls = fileURLs,
           !urls.isEmpty {
            let item = ClipboardItem(content: .files(urls))
            logReadItem(item, pasteboardTypes: pasteboardTypes)
            return item
        }

        if let string, !string.isEmpty {
            let item = ClipboardItem(content: .text(string))
            logReadItem(item, pasteboardTypes: pasteboardTypes)
            return item
        }

        if let image {
            let data = image.tiffRepresentation ?? Data()
            let item = ClipboardItem(content: .image(image, data))
            logImageItem(item, data: data, pasteboardTypes: pasteboardTypes)
            logReadItem(item, pasteboardTypes: pasteboardTypes)
            return item
        }

        AppLog.write("Read pasteboard item: empty; pasteboardTypes=\(formatPasteboardTypes(pasteboardTypes))")
        return nil
    }

    private static func hasFileURLs(in pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool {
        !filePasteboardTypes.isDisjoint(with: Set(pasteboardTypes))
    }

    private static func hasImage(in pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool {
        !imagePasteboardTypes.isDisjoint(with: Set(pasteboardTypes))
    }

    private static func hasString(in pasteboardTypes: [NSPasteboard.PasteboardType]) -> Bool {
        !stringPasteboardTypes.isDisjoint(with: Set(pasteboardTypes))
    }

    private static func logReadItem(_ item: ClipboardItem, pasteboardTypes: [NSPasteboard.PasteboardType]) {
        AppLog.write(
            "Read pasteboard item: contentType=\(item.contentType.rawValue); pasteboardTypes=\(formatPasteboardTypes(pasteboardTypes))"
        )
    }

    private static func logImageItem(_ item: ClipboardItem, data: Data, pasteboardTypes: [NSPasteboard.PasteboardType]) {
        guard case .image(let image, _) = item.content else { return }
        AppLog.write(
            "Read image diagnostics: size=\(Int(image.size.width))x\(Int(image.size.height)); dataBytes=\(data.count); fingerprint=\(shortFingerprint(item.fingerprint)); pasteboardTypes=\(formatPasteboardTypes(pasteboardTypes))"
        )
    }

    private static func shortFingerprint(_ fingerprint: String) -> String {
        String(fingerprint.prefix(24))
    }

    private static func formatPasteboardTypes(_ pasteboardTypes: [NSPasteboard.PasteboardType]) -> String {
        pasteboardTypes
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}

#if DEBUG
extension ClipboardStore {
    convenience init(previewItems: [ClipboardItem]) {
        self.init()
        items = previewItems
    }
}
#endif

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

private struct ClipboardHistorySaveSnapshot {
    let records: [PersistentClipboardItem]
    let persistenceURL: URL
    let encryptionKey: SymmetricKey
}
