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
    private static let richTextPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .rtf,
        NSPasteboard.PasteboardType("NeXT Rich Text Format v1.0 pasteboard type"),
        .rtfd,
        NSPasteboard.PasteboardType("com.apple.flat-rtfd"),
        .html,
        NSPasteboard.PasteboardType("Apple HTML pasteboard type"),
        NSPasteboard.PasteboardType("com.apple.webarchive"),
        NSPasteboard.PasteboardType("Apple Web Archive pasteboard type")
    ]
    private static let richTextPasteboardTypeSet = Set(richTextPasteboardTypes)
    private static let maxRichTextPayloadBytes = 12 * 1024 * 1024
    private static let saveCoalescingDelay: TimeInterval = 0.25
    private let persistenceURL: URL
    private let loadQueue = DispatchQueue(label: "com.warrfie.andpaste.history-load", qos: .utility)
    private let saveQueue = DispatchQueue(label: "com.warrfie.andpaste.history-save", qos: .utility)
    private var encryptionKey: SymmetricKey?
    private var persistedHistoryLoadState: PersistedHistoryLoadState = .notStarted
    private var lastChangeCount: Int
    private var timer: Timer?
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var pendingSaveSnapshot: ClipboardHistorySaveSnapshot?
    private var saveAfterPersistedHistoryLoad = false
    private var discardLoadedHistory = false

    private enum PersistedHistoryLoadState {
        case notStarted
        case loading
        case loaded
    }

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
        startPersistedHistoryLoad()
    }

    func stop() {
        AppLog.write("ClipboardStore stop")
        timer?.invalidate()
        timer = nil
        flushPendingSave()
    }

    func clearHistory() {
        startPersistedHistoryLoad()
        if persistedHistoryLoadState == .loading {
            discardLoadedHistory = true
        }
        items.removeAll { !$0.isPinned }
        saveItems()
    }

    func copyToPasteboard(
        _ item: ClipboardItem,
        asPlainText: Bool = false,
        preferFileForImages: Bool = false
    ) {
        pasteboard.clearContents()
        if asPlainText {
            pasteboard.setString(item.plainTextRepresentation, forType: .string)
            lastChangeCount = pasteboard.changeCount
            return
        }

        switch item.content {
        case .text(let text, let richTextPayloads):
            if !richTextPayloads.isEmpty {
                let richTypes = richTextPayloads.map(\.pasteboardTypeValue)
                pasteboard.declareTypes(richTypes + [.string], owner: nil)
                for payload in richTextPayloads {
                    pasteboard.setData(payload.data, forType: payload.pasteboardTypeValue)
                }
                pasteboard.setString(text, forType: .string)
            } else {
                pasteboard.setString(text, forType: .string)
            }
        case .image(let image, let data):
            if preferFileForImages, let url = Self.writeImageFile(image: image, fallbackData: data) {
                pasteboard.writeObjects([url as NSURL])
                AppLog.write("Copy image to pasteboard as file; url=\(url.path)")
            } else {
                pasteboard.writeObjects([image])
            }
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ item: ClipboardItem) {
        startPersistedHistoryLoad()
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        trimItems()
        saveItems()
    }

    func prepareForDisplay() {
        startPersistedHistoryLoad()
        if let item = ClipboardStore.readCurrentItem(from: pasteboard), !items.contains(where: { $0.fingerprint == item.fingerprint }) {
            add(item)
        }
    }

    private func pollPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let item = Self.readCurrentItem(from: pasteboard) else { return }
        startPersistedHistoryLoad()
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
        if persistedHistoryLoadState == .loading {
            saveAfterPersistedHistoryLoad = true
            return
        }

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

    nonisolated private static func writeSaveSnapshot(_ snapshot: ClipboardHistorySaveSnapshot) {
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

    private func startPersistedHistoryLoad() {
        guard persistedHistoryLoadState == .notStarted else { return }
        persistedHistoryLoadState = .loading

        let startedAt = Date()
        let url = persistenceURL
        let cachedEncryptionKey = encryptionKey
        guard FileManager.default.fileExists(atPath: url.path) else {
            persistedHistoryLoadState = .loaded
            AppLog.write("Clipboard history preload skipped; no persisted history")
            return
        }

        loadQueue.async { [weak self] in
            let encryptionKey: SymmetricKey?
            if let cachedEncryptionKey {
                encryptionKey = cachedEncryptionKey
            } else {
                AppLog.write("Loading clipboard history encryption key")
                encryptionKey = try? ClipboardHistoryKeychain.loadOrCreateKey()
                if encryptionKey == nil {
                    AppLog.write("Clipboard history encryption key is unavailable")
                }
            }

            let loadedItems = Self.loadItems(from: url, encryptionKey: encryptionKey)
            Task { @MainActor [weak self] in
                self?.finishPersistedHistoryLoad(
                    loadedItems,
                    encryptionKey: encryptionKey,
                    startedAt: startedAt
                )
            }
        }
    }

    private func finishPersistedHistoryLoad(
        _ loadedItems: [ClipboardItem],
        encryptionKey: SymmetricKey?,
        startedAt: Date
    ) {
        if let encryptionKey {
            self.encryptionKey = encryptionKey
        }

        if !discardLoadedHistory {
            let existingFingerprints = Set(items.map(\.fingerprint))
            let newItems = loadedItems.filter { !existingFingerprints.contains($0.fingerprint) }
            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
                sortItems()
                trimItems()
            }
        }

        persistedHistoryLoadState = .loaded
        discardLoadedHistory = false
        AppLog.write(
            "Clipboard history preload completed; itemCount=\(items.count); duration=\(String(format: "%.3f", Date().timeIntervalSince(startedAt)))s"
        )

        if saveAfterPersistedHistoryLoad {
            saveAfterPersistedHistoryLoad = false
            saveItems()
        }
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

    nonisolated private static func loadItems(from url: URL, encryptionKey: SymmetricKey?) -> [ClipboardItem] {
        guard let encryptionKey else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let plainData = try ClipboardHistoryEncryption.decrypt(data, using: encryptionKey)
            let records = try JSONDecoder().decode([PersistentClipboardItem].self, from: plainData)
            return records.compactMap(\.item)
        } catch {
            AppLog.write("Unable to load clipboard history: \(error.localizedDescription)")
            return []
        }
    }

    private static func defaultPersistenceURL() -> URL {
        applicationSupportURL()
            .appendingPathComponent("history.cphistory")
    }

    static func imageExportURL(in directory: URL, date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let filename = "andPaste Image \(formatter.string(from: date)).png"
        return directory.appendingPathComponent(filename)
    }

    static func pngData(for image: NSImage, fallbackData: Data) -> Data? {
        let imageData = image.tiffRepresentation ?? (fallbackData.isEmpty ? nil : fallbackData)
        guard let imageData,
              let bitmap = NSBitmapImageRep(data: imageData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func writeImageFile(image: NSImage, fallbackData: Data) -> URL? {
        guard let pngData = pngData(for: image, fallbackData: fallbackData) else {
            AppLog.write("Copy image as file skipped: unable to create PNG data")
            return nil
        }

        let directory = applicationSupportURL()
            .appendingPathComponent("Pasteboard Image Files", isDirectory: true)
        let url = imageExportURL(in: directory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            AppLog.write("Copy image as file skipped: \(error.localizedDescription)")
            return nil
        }
    }

    private static func applicationSupportURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("andPaste", isDirectory: true)
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
        let richTextPayloads = richTextPayloads(from: pasteboard, pasteboardTypes: pasteboardTypes)

        return makeItem(
            fileURLs: fileURLs,
            string: string,
            richTextPayloads: richTextPayloads,
            image: image,
            pasteboardTypes: pasteboardTypes
        )
    }

    static func makeItem(
        fileURLs: [URL]?,
        string: String?,
        richTextPayloads: [ClipboardItem.RichTextPayload] = [],
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
            let item = ClipboardItem(content: .text(string, richTextPayloads: richTextPayloads))
            logRichTextItem(richTextPayloads: richTextPayloads, pasteboardTypes: pasteboardTypes)
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

    private static func richTextPayloads(
        from pasteboard: NSPasteboard,
        pasteboardTypes: [NSPasteboard.PasteboardType]
    ) -> [ClipboardItem.RichTextPayload] {
        var payloads: [ClipboardItem.RichTextPayload] = []
        for type in pasteboardTypes where richTextPasteboardTypeSet.contains(type) {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            guard data.count <= maxRichTextPayloadBytes else {
                AppLog.write("Skipped rich text payload: type=\(type.rawValue); bytes=\(data.count); maxBytes=\(maxRichTextPayloadBytes)")
                continue
            }
            payloads.append(ClipboardItem.RichTextPayload(pasteboardType: type.rawValue, data: data))
        }
        return payloads
    }

    private static func logReadItem(_ item: ClipboardItem, pasteboardTypes: [NSPasteboard.PasteboardType]) {
        AppLog.write(
            "Read pasteboard item: contentType=\(item.contentType.rawValue); pasteboardTypes=\(formatPasteboardTypes(pasteboardTypes))"
        )
    }

    private static func logRichTextItem(
        richTextPayloads: [ClipboardItem.RichTextPayload],
        pasteboardTypes: [NSPasteboard.PasteboardType]
    ) {
        guard !richTextPayloads.isEmpty else { return }
        let stored = richTextPayloads
            .map { "\($0.pasteboardType)(\($0.data.count)b)" }
            .joined(separator: ",")
        let skipped = pasteboardTypes
            .filter { !richTextPasteboardTypeSet.contains($0) }
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
        AppLog.write("Read rich text diagnostics: stored=\(stored); skippedTypes=\(skipped)")
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
    let richText: ClipboardItem.RichTextPayload?
    let richTextPayloads: [ClipboardItem.RichTextPayload]?
    let imageData: Data?
    let fileURLs: [URL]?

    init?(item: ClipboardItem) {
        id = item.id
        createdAt = item.createdAt
        isPinned = item.isPinned
        switch item.content {
        case .text(let value, let richTextPayloads):
            kind = .text
            text = value
            richText = richTextPayloads.first
            self.richTextPayloads = richTextPayloads
            imageData = nil
            fileURLs = nil
        case .image(_, let data):
            kind = .image
            text = nil
            richText = nil
            richTextPayloads = nil
            imageData = data
            fileURLs = nil
        case .files(let urls):
            kind = .files
            text = nil
            richText = nil
            richTextPayloads = nil
            imageData = nil
            fileURLs = urls
        }
    }

    var item: ClipboardItem? {
        switch kind {
        case .text:
            guard let text else { return nil }
            return ClipboardItem(
                id: id,
                content: .text(text, richTextPayloads: richTextPayloads ?? richText.map { [$0] } ?? []),
                createdAt: createdAt,
                isPinned: isPinned
            )
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
