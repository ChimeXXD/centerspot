import CoreGraphics
import Foundation

/// How a library card draws the board (D-74, mockup `library--compact` and `ipad-library`). The same `BoardRenderer`
/// draws it (D-07); this only turns the drawing and sets the sizes a small board needs:
/// - the whole pitch turned a quarter clockwise, so our goal is on the left and we attack right; numbers stay upright;
/// - discs 1.5 times the board's (5.7% of the pitch's short side), with the thin dark outline (D-67);
/// - numbers only when they come out at 7 pt or more; smaller, the discs are plain: home filled, away rings (D-15);
/// - pitch lines at least 0.75 pt, marks at least 1.2 pt, arrows at least the mockup's 0.55 scale.
struct CardStyle: Sendable, Equatable {
    var sideways = true
    var tokenScale: CGFloat = 1.5
    /// Numbers smaller than this are left off (the mockup's `MIN_NUMBER_PT`).
    var minimumNumberSize: CGFloat = 7
    var minimumPitchLine: CGFloat = 0.75
    var minimumMarkLine: CGFloat = 1.2
    /// Arrows keep at least this scale of their 345 pt sizes (the mockup's `thumbArrow` k = 0.55: a 1.43 pt line).
    var minimumArrowScale: CGFloat = 0.55
    /// The disc's dark outline is at least this wide (the mockup's 0.6).
    var minimumOutline: CGFloat = 0.6

    static let card = CardStyle()
    /// The library's tall card (D-89): the pitch upright, the shape of the 9:16 video; it is taller than the old
    /// sideways card, so its discs need less help (1.1 times the board's).
    static let upright = CardStyle(sideways: false, tokenScale: 1.1)

    /// Whether a disc of radius `r` (already scaled) gets its number.
    func showsNumbers(radius r: CGFloat) -> Bool {
        r * TokenDrawing.numberSizeRatio >= minimumNumberSize
    }

    /// Whether a card whose pitch is `length` points long (sideways, so this is its width on screen) shows numbers.
    /// The mockup's notes: a pitch at least 181 pt long, so a card at least 201 pt wide.
    func showsNumbers(pitchLength length: CGFloat, kind: Pitch.Kind = .full) -> Bool {
        let rect = CGRect(x: 0, y: 0, width: length, height: BoardGeometry.width(forLength: length, kind: kind))
        return showsNumbers(radius: geometry(kind: kind, in: rect).tokenRadius)
    }

    /// The upright board's geometry for a card drawn into `rect`, with the card's disc size.
    func geometry(kind: Pitch.Kind, in rect: CGRect) -> BoardGeometry {
        var g = BoardGeometry(kind: kind, fitting: sideways ? Self.uprightRect(for: rect) : rect)
        g.tokenScale = tokenScale
        return g
    }

    /// The rect the upright board is drawn in before the turn: `rect`'s size swapped, at the origin.
    static func uprightRect(for rect: CGRect) -> CGRect {
        CGRect(x: 0, y: 0, width: rect.height, height: rect.width)
    }

    /// A quarter turn clockwise (y-down) from the upright rect into `rect`: upright (x, y) lands at
    /// (rect.maxX − y, rect.minY + x), so the top of the upright pitch (the opponent's goal) is on the right and its
    /// left touchline along the top. Exact integers, so the turn adds no rounding of its own.
    static func sidewaysTransform(into rect: CGRect) -> CGAffineTransform {
        CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: rect.maxX, ty: rect.minY)
    }
}
