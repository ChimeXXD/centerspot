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
    /// Discs drawn this many times the board's size (library cards: 1.5, D-74). Everywhere else 1.
    var tokenScale: CGFloat = 1

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

    /// The pitch's width for a given length (a sideways card's height for its width).
    static func width(forLength length: CGFloat, kind: Pitch.Kind) -> CGFloat {
        length * CGFloat(kind.size.width / kind.size.length)
    }

    var tokenRadius: CGFloat { pitchRect.width * Self.tokenRadiusRatio * tokenScale }

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
    /// the number). During playback `carry` (from `Timeline`) eases that offset across each move, so a pass glides
    /// off one player and onto the next (Chime's recording, 7 Nov: a 17.6 pt leap in one frame). While editing it
    /// is empty and the offset eases with the nearest player's distance (`carryWeight`).
    func drawnCentres(positions: [String: Point], tokens: [Token], carry: [String: Double] = [:]) -> [String: CGPoint] {
        let r = tokenRadius
        var centres: [String: CGPoint] = [:]
        for token in tokens { if let p = positions[token.id] { centres[token.id] = point(p) } }
        for token in tokens where token.kind == .ball {
            guard let c = centres[token.id] else { continue }
            let nearest = tokens.filter { $0.kind == .player }
                .compactMap { centres[$0.id].map { hypot($0.x - c.x, $0.y - c.y) } }
                .min()
            guard let nearest else { continue }
            let w = carry[token.id].map { CGFloat($0) } ?? Self.carryWeight(radii: nearest / r)
            centres[token.id] = CGPoint(x: c.x + r * 0.95 * w, y: c.y + r * 0.95 * w)
        }
        return centres
    }

    /// The carry offset's weight for a player `radii` disc radii from the ball (`Possession.carryWeight`): whole up
    /// to `carryFull`, none from `carryNone` = `Possession.reach`, eased between, so a loose ball is drawn where it is.
    static func carryWeight(radii: CGFloat) -> CGFloat {
        CGFloat(Possession.carryWeight(radii: Double(radii)))
    }

    static let carryFull = CGFloat(Possession.fullCarryRadii)
    static let carryNone = CGFloat(Possession.noCarryRadii)

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

    /// The token a drawn stroke starts on (D-59): a player within `hitRadius` first, so a stroke from the ball at a
    /// carrier's feet starts on the carrier; a loose ball nearer the finger than any player starts its own stroke;
    /// else nil (grass, or a cone).
    func strokeStart(at location: CGPoint, positions: [String: Point], tokens: [Token]) -> String? {
        let centres = drawnCentres(positions: positions, tokens: tokens)
        func nearest(_ kind: Token.Kind) -> (id: String, distance: CGFloat)? {
            tokens.filter { $0.kind == kind }
                .compactMap { token in centres[token.id].map { (token.id, hypot($0.x - location.x, $0.y - location.y)) } }
                .filter { $0.1 <= Self.hitRadius }
                .min { $0.1 < $1.1 }
        }
        let player = nearest(.player), ball = nearest(.ball)
        // A ball out of every player's reach (`Possession`) is loose and starts its own stroke when it's nearer.
        let aspect = Double(pitchRect.height / pitchRect.width)
        if let ball, let p = positions[ball.id],
           Possession.carrier(ofBallAt: p, positions: positions, tokens: tokens, aspect: aspect) == nil,
           ball.distance < player?.distance ?? .infinity {
            return ball.id
        }
        return player?.id ?? ball?.id
    }
}
