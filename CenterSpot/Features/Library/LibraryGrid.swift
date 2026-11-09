import SwiftUI

/// The library's layout (D-89, mockup `library-v2--phone` and `library-v2--ipad`), worked out from the window's width,
/// not the device: an iPhone, an iPad in portrait and an iPad in Split View each get what fits.
///
/// - Compact (phones, narrow windows): one column of content with 16 pt margins; tall cards two a row, 12 pt apart.
/// - Wide (from 744 pt, an iPad mini upright): a 280 pt sidebar, then 32 pt margins and tall cards at least 176 pt
///   wide, 16 pt apart, at most 6 a row. A 13-inch iPad in landscape shows 5 (193.6 pt cards, as in the mockup), portrait 3.
/// - At the accessibility text sizes half as many columns (one on a phone), so two-line titles stay readable.
struct LibraryGrid: Equatable {
    enum Style: Equatable { case compact, wide }

    let style: Style
    let columns: Int
    /// The content's side margin.
    let margin: CGFloat
    let cardWidth: CGFloat

    static let compactMargin: CGFloat = 16
    static let wideMargin: CGFloat = 32
    /// Windows at least this wide get the sidebar.
    static let wideWindow: CGFloat = 744
    static let sidebarWidth: CGFloat = 280
    static let minimumWideCard: CGFloat = 176
    static let maximumColumns = 6

    init(width: CGFloat, accessibilityText: Bool = false) {
        let wide = width >= Self.wideWindow
        style = wide ? .wide : .compact
        margin = wide ? Self.wideMargin : Self.compactMargin
        let content = max(0, width - (wide ? Self.sidebarWidth : 0) - 2 * margin)
        let gap: CGFloat = wide ? 16 : 12
        var count = wide ? min(Self.maximumColumns, max(1, Int(((content + gap) / (Self.minimumWideCard + gap)).rounded(.down)))) : 2
        if accessibilityText { count = max(1, count / 2) }
        columns = count
        cardWidth = max(0, (content - gap * CGFloat(count - 1)) / CGFloat(count))
    }

    var isWide: Bool { style == .wide }
    var columnGap: CGFloat { isWide ? 16 : 12 }
    var rowGap: CGFloat { isWide ? 24 : 20 }
}
