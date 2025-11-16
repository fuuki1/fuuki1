import SwiftUI

// MARK: - Tips Flow Layout

/// A layout that wraps items horizontally like tags
struct TipsFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 6
    var maxItemWidth: CGFloat = 240

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        guard width.isFinite else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        for sub in subviews {
            let item = sub.sizeThatFits(ProposedViewSize(width: min(width, maxItemWidth), height: nil))
            if x > 0 && x + item.width > width {
                x = 0
                y += rowH + lineSpacing
                rowH = 0
            }
            x += item.width + spacing
            rowH = max(rowH, item.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0
        for sub in subviews {
            let available = bounds.width
            let itemSize = sub.sizeThatFits(ProposedViewSize(width: min(available, maxItemWidth), height: nil))
            if x > bounds.minX && x + itemSize.width > bounds.maxX {
                x = bounds.minX
                y += rowH + lineSpacing
                rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: itemSize.width, height: itemSize.height))
            x += itemSize.width + spacing
            rowH = max(rowH, itemSize.height)
        }
    }
}
