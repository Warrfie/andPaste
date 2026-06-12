import CoreGraphics

enum ClipboardHistoryLayout {
    static let windowWidth: CGFloat = 520
    static let maxWindowHeight: CGFloat = 620
    static let headerHeight: CGFloat = 52
    static let emptyStateHeight: CGFloat = 160
    static let maxListHeight: CGFloat = 320
    static let detailHeight: CGFloat = 220
    static let rowVerticalPadding: CGFloat = 20
    static let textRowContentHeight: CGFloat = 52
    static let imageRowContentHeight: CGFloat = 112

    static func rowHeight(for item: ClipboardItem) -> CGFloat {
        switch item.content {
        case .image:
            return imageRowContentHeight + rowVerticalPadding
        case .text, .files:
            return textRowContentHeight + rowVerticalPadding
        }
    }

    static func listHeight(for items: [ClipboardItem]) -> CGFloat {
        guard !items.isEmpty else { return emptyStateHeight }
        let totalHeight = items.reduce(0) { $0 + rowHeight(for: $1) }
        return min(totalHeight, maxListHeight)
    }

    static func contentHeight(filteredItems: [ClipboardItem], hasSelection: Bool) -> CGFloat {
        let bodyHeight = listHeight(for: filteredItems) + (hasSelection ? detailHeight : 0)
        return min(headerHeight + bodyHeight, maxWindowHeight)
    }
}
