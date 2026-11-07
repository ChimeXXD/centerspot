import Foundation

/// Who has the ball: a player within `reach` of it, measured as it looks on the pitch. One rule for drawing strokes
/// (D-62: a pass or dribble moves the ball only from its carrier), for the timeline (a carried ball rides along its
/// carrier's run) and for where the ball is drawn (`carryWeight`).
enum Possession {
    /// A player disc's radius in pitch widths (`BoardGeometry.tokenRadiusRatio`).
    static let discRadius = 0.038
    /// The ball is drawn wholly at a player's feet up to this many disc radii from them…
    static let fullCarryRadii = 0.8
    /// …and where it is from this many (the reach), eased between.
    static let noCarryRadii = 1.2
    /// 1.2 disc radii in pitch widths.
    static let reach = discRadius * noCarryRadii

    /// Distance between two normalised points in pitch widths, with the pitch's length over width as `aspect`.
    static func distance(_ a: Point, _ b: Point, aspect: Double) -> Double {
        hypot(a.x - b.x, (a.y - b.y) * aspect)
    }

    /// The nearest player within `reach` of the ball, or nil when it's loose.
    static func carrier(ofBallAt ball: Point, positions: [String: Point], tokens: [Token], aspect: Double) -> String? {
        guard let nearest = nearestPlayer(to: ball, positions: positions, tokens: tokens, aspect: aspect),
              nearest.distance < reach else { return nil }
        return nearest.id
    }

    /// How far the ball is drawn towards its carrier's feet (0…1) for a nearest player `radii` disc radii away:
    /// whole up to `fullCarryRadii`, none from `noCarryRadii`, smoothstepped between.
    static func carryWeight(radii: Double) -> Double {
        let x = ((noCarryRadii - radii) / (noCarryRadii - fullCarryRadii)).clamped(to: 0...1)
        return x * x * (3 - 2 * x)
    }

    /// `carryWeight` for a ball at `ball` (0 with no players). The renderer works out the same weight from drawn
    /// distances, so the timeline's weight at rest matches the editor's.
    static func carryWeight(ofBallAt ball: Point, positions: [String: Point], tokens: [Token], aspect: Double) -> Double {
        guard let nearest = nearestPlayer(to: ball, positions: positions, tokens: tokens, aspect: aspect) else { return 0 }
        return carryWeight(radii: nearest.distance / discRadius)
    }

    private static func nearestPlayer(to ball: Point, positions: [String: Point], tokens: [Token],
                                      aspect: Double) -> (id: String, distance: Double)? {
        tokens.filter { $0.kind == .player }
            .compactMap { token in positions[token.id].map { (id: token.id, distance: distance($0, ball, aspect: aspect)) } }
            .min { $0.distance < $1.distance }
    }
}
