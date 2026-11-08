import SwiftUI

/// The library's card grid (D-74, mockup `library--compact` and `ipad-library`), worked out from the width the screen
/// has, not the device: an iPhone, an iPad in portrait and an iPad in Split View each get what fits.
///
/// - Compact (phones, narrow windows): 24 pt margins, cards at least 100 pt wide with 10 pt between them, so an iPhone
///   shows 3 a row (108 pt cards, a 92 pt pitch: too small for numbers).
/// - Wide (from 635 pt of content: three cards that can carry numbers): 32 pt margins, cards at least 201 pt wide, so
///   their numbers come out at 7 pt (`CardStyle`), 16 pt apart, at most 6 a row. A 13-inch iPad in landscape shows 6
///   (205 pt cards, a 185 pt pitch), an 11-inch 5, portrait 3 or 4.
/// - At the accessibility text sizes a third as many columns, so two-line titles stay readable.
struct LibraryGrid: Equatable {
    enum Style: Equatable { case compact, wide }

    let style: Style
    let columns: Int
    /// The page's side margin.
    let margin: CGFloat
    let cardWidth: CGFloat

    static let wideMargin: CGFloat = 32
    static let compactMargin: CGFloat = 24
    /// Windows at least this wide take the wide margin.
    static let wideWindow: CGFloat = 700
    static let minimumCompactCard: CGFloat = 100
    /// The narrowest card whose numbers reach 7 pt (the mockup's 201 pt).
    static let minimumWideCard: CGFloat = 201
    static let maximumColumns = 6

    init(width: CGFloat, accessibilityText: Bool = false) {
        margin = width >= Self.wideWindow ? Self.wideMargin : Self.compactMargin
        let content = max(0, width - 2 * margin)
        let wideGap: CGFloat = 16, compactGap: CGFloat = 10
        let fitsWide = content >= 3 * Self.minimumWideCard + 2 * wideGap
        style = fitsWide ? .wide : .compact
        let gap = fitsWide ? wideGap : compactGap
        let minimum = fitsWide ? Self.minimumWideCard : Self.minimumCompactCard
        var count = min(Self.maximumColumns, max(1, Int(((content + gap) / (minimum + gap)).rounded(.down))))
        if accessibilityText { count = max(1, count / 3) }
        columns = count
        cardWidth = max(0, (content - gap * CGFloat(count - 1)) / CGFloat(count))
    }

    var isWide: Bool { style == .wide }
    var columnGap: CGFloat { isWide ? 16 : 10 }
    var rowGap: CGFloat { isWide ? 16 : 12 }
    /// Padding plus the tile's 2 pt border, on the sides and the top (the mockup's 6 + 2 and 8 + 2).
    var inset: CGFloat { isWide ? 10 : 8 }
    var bottomInset: CGFloat { isWide ? 12 : 10 }
    var cornerRadius: CGFloat { isWide ? 16 : 14 }
    /// The thumbnail's own corners (the mockup's 5 px on the svg).
    static let thumbnailCorner: CGFloat = 5
    var nameSize: CGFloat { isWide ? 15 : 13 }
    var metaSize: CGFloat { isWide ? 12 : 11 }
    /// The name: heavy Nunito at the mockup's size, scaling with Dynamic Type.
    var nameFont: Font {
        Font.custom(Tokens.Typeface.uiName, size: nameSize, relativeTo: isWide ? .subheadline : .footnote).weight(.bold)
    }
    /// "5 steps".
    var metaFont: Font {
        Font.custom(Tokens.Typeface.uiName, size: metaSize, relativeTo: isWide ? .caption : .caption2).weight(.medium)
    }
    var nameGap: CGFloat { isWide ? 8 : 6 }
    static let metaGap: CGFloat = 2

    /// The sideways pitch's length on a card: its width inside the padding.
    var pitchLength: CGFloat { cardWidth - 2 * inset }
}
