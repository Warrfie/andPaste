import AppKit
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardStore
    let onClose: () -> Void
    let onSelect: (ClipboardItem, PasteMode) -> Void

    @State private var query = ""
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var keyDownMonitor: Any?
    @State private var pasteMode: PasteMode = .plainText

    private var filteredItems: [ClipboardItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return store.items }
        return store.items.filter { $0.searchText.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private var selectedItem: ClipboardItem? {
        guard let selectedItemID else { return nil }
        return store.items.first { $0.id == selectedItemID }
    }

    private var listHeight: CGFloat {
        ClipboardHistoryLayout.listHeight(for: filteredItems)
    }

    private var contentHeight: CGFloat {
        ClipboardHistoryLayout.contentHeight(filteredItems: filteredItems, hasSelection: selectedItem != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isSelected: item.id == selectedItemID,
                                onTogglePin: {
                                    store.togglePin(item)
                                },
                                onPaste: {
                                    selectedItemID = item.id
                                    onSelect(item, pasteMode)
                                }
                            ) {
                                selectedItemID = item.id
                            }
                        }
                    }
                }
                .frame(height: listHeight)
            }

            if let selectedItem {
                ClipboardDetailView(item: selectedItem) {
                    toggleSelectedPin()
                }
                    .frame(height: ClipboardHistoryLayout.detailHeight)
            }
        }
        .frame(width: ClipboardHistoryLayout.windowWidth, height: contentHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            selectDefaultItemIfNeeded()
            installKeyboardMonitorIfNeeded()
            HistoryWindowSupport.resizeHistoryWindow(width: ClipboardHistoryLayout.windowWidth, height: contentHeight)
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: contentHeight) { newHeight in
            HistoryWindowSupport.resizeHistoryWindow(width: ClipboardHistoryLayout.windowWidth, height: newHeight)
        }
        .onChange(of: filteredItems.map(\.id)) { _ in
            selectDefaultItemIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Close")

            HeaderDragArea()
                .frame(minWidth: 16, maxWidth: .infinity, minHeight: 28)

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            PasteSplitButton(
                isEnabled: selectedItem != nil,
                onPaste: {
                    pasteSelected(mode: pasteMode)
                },
                onSelectPlainText: {
                    pasteMode = .plainText
                }
            )
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(store.items.isEmpty ? "Clipboard history is empty" : "No matches")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pasteSelected(mode: PasteMode) {
        guard let selectedItem else { return }
        onSelect(selectedItem, mode)
    }

    private func toggleSelectedPin() {
        guard let selectedItemID,
              let item = store.items.first(where: { $0.id == selectedItemID }) else { return }
        store.togglePin(item)
    }

    private func selectDefaultItemIfNeeded() {
        if let selectedItemID, filteredItems.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = filteredItems.first?.id
    }

    private func selectAdjacentItem(offset: Int) {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }

        guard let currentSelectionID = selectedItemID,
              let currentIndex = filteredItems.firstIndex(where: { $0.id == currentSelectionID }) else {
            selectedItemID = filteredItems.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), filteredItems.count - 1)
        selectedItemID = filteredItems[nextIndex].id
    }

    private func installKeyboardMonitorIfNeeded() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard HistoryWindowSupport.owns(event) else { return event }
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else { return event }

            switch event.keyCode {
            case 36:
                pasteSelected(mode: .plainText)
                return nil
            case 53:
                onClose()
                return nil
            case 125:
                selectAdjacentItem(offset: 1)
                return nil
            case 126:
                selectAdjacentItem(offset: -1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }
    }
}

private struct HeaderDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onTogglePin: () -> Void
    let onPaste: () -> Void
    let onSelect: () -> Void

    static func height(for item: ClipboardItem) -> CGFloat {
        ClipboardHistoryLayout.rowHeight(for: item)
    }

    var body: some View {
        HStack(spacing: 12) {
            content

            ClipboardContentTypeBadge(displayType: item.displayType)

            Button(action: onTogglePin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .help(item.isPinned ? "Unpin" : "Pin")

            Text(item.createdAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 54, alignment: .center)
        }
        .frame(minHeight: rowMinimumHeight, alignment: .center)
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(perform: onSelect)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            Rectangle()
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }

    private var rowMinimumHeight: CGFloat {
        switch item.content {
        case .image:
            return ClipboardHistoryLayout.imageRowContentHeight
        case .text, .files:
            return ClipboardHistoryLayout.textRowContentHeight
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .image(let image, _):
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .center)
                .clipped()
        case .text, .files:
            Text(item.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ClipboardContentTypeBadge: View {
    let displayType: ClipboardItem.DisplayType

    var body: some View {
        Image(systemName: displayType.systemImageName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            .help(displayType.title)
    }
}

private struct PasteSplitButton: View {
    let isEnabled: Bool
    let onPaste: () -> Void
    let onSelectPlainText: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onPaste) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(Color.white.opacity(0.32))
                .frame(width: 1, height: 16)

            Menu {
                Button(action: onSelectPlainText) {
                    Label("Paste Plain Text", systemImage: "checkmark")
                }
            } label: {
                Color.clear
                    .frame(width: 1, height: 24)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .frame(width: 18, height: 24)
            .clipped()
        }
        .foregroundStyle(.white)
        .background(isEnabled ? Color.accentColor : Color(nsColor: .disabledControlTextColor).opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(isEnabled ? 1 : 0.55)
        .allowsHitTesting(isEnabled)
        .help("Paste")
    }
}

private struct ClipboardDetailView: View {
    let item: ClipboardItem
    let onTogglePin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button(action: onTogglePin) {
                    Label(item.isPinned ? "Pinned" : "Pin", systemImage: item.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                detailContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch item.content {
        case .text(let text):
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
        case .image(let image, _):
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .center)
        case .files(let urls):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(urls, id: \.self) { url in
                    Text(url.path)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

#if DEBUG
struct ClipboardHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ClipboardHistoryView(
            store: ClipboardStore(previewItems: PreviewClipboardData.items),
            onClose: {},
            onSelect: { _, _ in }
        )
        .previewDisplayName("Clipboard History")
    }
}

private enum PreviewClipboardData {
    static let items: [ClipboardItem] = [
        ClipboardItem(
            content: .text("Paste history preview with enough text to show wrapping and the detail pane below."),
            createdAt: Date(),
            isPinned: true
        ),
        ClipboardItem(
            content: .image(sampleImage, sampleImage.tiffRepresentation ?? Data()),
            createdAt: Date().addingTimeInterval(-120)
        ),
        ClipboardItem(
            content: .files([URL(fileURLWithPath: "/Users/example/Desktop/example.png")]),
            createdAt: Date().addingTimeInterval(-360)
        )
    ]

    private static var sampleImage: NSImage {
        let image = NSImage(size: NSSize(width: 240, height: 140))
        image.lockFocus()
        NSColor.controlAccentColor.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 240, height: 140)).fill()
        NSColor.white.withAlphaComponent(0.9).setFill()
        NSBezierPath(roundedRect: NSRect(x: 28, y: 32, width: 184, height: 76), xRadius: 12, yRadius: 12).fill()
        NSColor.controlAccentColor.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: 52, y: 52, width: 36, height: 36)).fill()
        image.unlockFocus()
        return image
    }
}
#endif
