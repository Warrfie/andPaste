import AppKit
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardStore
    let onClose: () -> Void
    let onSelect: (ClipboardItem) -> Void

    @State private var query = ""
    @State private var selectedItemID: ClipboardItem.ID?

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
                                isSelected: item.id == selectedItemID
                            ) {
                                selectedItemID = item.id
                            }
                        }
                    }
                }
                .frame(height: listHeight)
            }

            if let selectedItem {
                ClipboardDetailView(item: selectedItem)
                    .frame(height: ClipboardHistoryLayout.detailHeight)
            }
        }
        .frame(width: ClipboardHistoryLayout.windowWidth, height: contentHeight)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            HistoryWindowSupport.resizeHistoryWindow(width: ClipboardHistoryLayout.windowWidth, height: contentHeight)
        }
        .onChange(of: contentHeight) { newHeight in
            HistoryWindowSupport.resizeHistoryWindow(width: ClipboardHistoryLayout.windowWidth, height: newHeight)
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

            Spacer(minLength: 16)

            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            Button("Paste") {
                guard let selectedItem else { return }
                onSelect(selectedItem)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedItem == nil)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
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
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void

    static func height(for item: ClipboardItem) -> CGFloat {
        ClipboardHistoryLayout.rowHeight(for: item)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                content

                Text(item.createdAt, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 54, alignment: .center)
            }
            .frame(minHeight: rowMinimumHeight, alignment: .center)
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

private struct ClipboardDetailView: View {
    let item: ClipboardItem

    var body: some View {
        ScrollView {
            detailContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
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
