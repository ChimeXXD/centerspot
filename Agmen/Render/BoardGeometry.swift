import CoreGraphics
import Foundation

/// Where the pitch sits in a rect and how normalised points (D-05) map to points on it. The only place
/// positions become points; the renderer, gestures, hit-testing and the accessibility layer all use it.
/// Rects are in a y-down space (SwiftUI, or a flipped bitmap context).
struct BoardGeometry: Sendable, Equatable {
    /// Player discs are this fraction of the pitch width (the mockup's `W × 0.038`).
    static let tokenRadiusRatio: CGFloat = 0.038
    /// The mockup's reference pitch width: line widths and arrow sizes scale with `width / 345`.
    static let referenceWidth: CGFloat = 345
    /// A finger within this many points of a token's centre hits it, even when the disc is drawn smaller.
    static let hitRadius: CGFloat = 22
    /// Full-pitch metres; markings keep full-pitch proportions on every kind, as `Placement` measures zones.
    static let markingLength: CGFloat = 105
    static let markingWidth: CGFloat = 68

    /// The pitch: vertical, attacking upward, fitted inside the rect at its kind's aspect and centred.
    let pitchRect: CGRect

    init(kind: Pitch.Kind, fitting rect: CGRect) {
        let aspect = CGFloat(kind.size.length / kind.size.width)  // height ÷ width
        var size = CGSize(width: rect.width, height: rect.width * aspect)
        if size.height > rect.height { size = CGSize(width: rect.height / aspect, height: rect.height) }
        pitchRect = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                           width: size.width, height: size.height)
    }

    /// A pitch drawn into exactly `pitchRect`, whatever its aspect (the formation picker's small diagrams).
    init(pitchRect: CGRect) {
        self.pitchRect = pitchRect
    }

    /// The pitch rect's height for a given width (layout uses it to size the board).
    static func height(forWidth width: CGFloat, kind: Pitch.Kind) -> CGFloat {
        width * CGFloat(kind.size.length / kind.size.width)
    }

    var tokenRadius: CGFloat { pitchRect.width * Self.tokenRadiusRatio }

    /// Line and arrow scale: 1 at the mockup's 345 pt pitch.
    var scale: CGFloat { pitchRect.width / Self.referenceWidth }

    /// A normalised point on the pitch as a point in the rect (y = 1 is the top, the opponent's goal line).
    func point(_ p: Point) -> CGPoint {
        CGPoint(x: pitchRect.minX + CGFloat(p.x) * pitchRect.width,
                y: pitchRect.minY + CGFloat(1 - p.y) * pitchRect.height)
    }

    /// The inverse of `point(_:)`, not clamped (drags clamp through `TacticEdits.moveToken`).
    func normalised(_ point: CGPoint) -> Point {
        Point(x: Double((point.x - pitchRect.minX) / pitchRect.width),
              y: Double(1 - (point.y - pitchRect.minY) / pitchRect.height))
    }

    /// Full-pitch metres (x across 0…68, y from the top goal line 0…105) to a point, for the markings.
    func metres(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: pitchRect.minX + x / Self.markingWidth * pitchRect.width,
                y: pitchRect.minY + y / Self.markingLength * pitchRect.height)
    }

    /// Metres to points along each axis (equal on a full pitch; slightly different on 7- and 5-a-side).
    var metreScale: (x: CGFloat, y: CGFloat) {
        (pitchRect.width / Self.markingWidth, pitchRect.height / Self.markingLength)
    }

    /// Where each token is drawn. The ball sits at its carrier's feet (down and right of the disc, never over
    /// the number) when a player stands within 1.2 radii of it.
    func drawnCentres(positions: [String: Point], tokens: [Token]) -> [String: CGPoint] {
        let r = tokenRadius
        var centres: [String: CGPoint] = [:]
        for token in tokens { if let p = positions[token.id] { centres[token.id] = point(p) } }
        for token in tokens where token.kind == .ball {
            guard let c = centres[token.id] else { continue }
            let carried = tokens.contains { other in
                guard other.kind == .player, let o = centres[other.id] else { return false }
                return hypot(o.x - c.x, o.y - c.y) < r * 1.2
            }
            if carried { centres[token.id] = CGPoint(x: c.x + r * 0.95, y: c.y + r * 0.95) }
        }
        return centres
    }

    /// The token nearest `location` within `hitRadius`, or nil. Ties go to the token drawn on top (later in `tokens`,
    /// the ball last).
    func hitToken(at location: CGPoint, positions: [String: Point], tokens: [Token]) -> String? {
        let centres = drawnCentres(positions: positions, tokens: tokens)
        var best: (id: String, distance: CGFloat)?
        for token in BoardRenderer.drawingOrder(tokens) {
            guard let c = centres[token.id] else { continue }
            let d = hypot(c.x - location.x, c.y - location.y)
            if d <= Self.hitRadius, d <= (best?.distance ?? .infinity) { best = (token.id, d) }
        }
        return best?.id
    }
}
