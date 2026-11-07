import Foundation

/// D-40: where a spotlit player has just been, for the fading trail in an export. Read from `Timeline`, so the trail
/// is the path the player really takes; pure, so every export of a tactic draws the same trail.
enum SpotlightTrail {
    /// How far back the trail reaches, in seconds of the move.
    static let length = 0.8
    /// Samples along it, oldest first.
    static let samples = 16

    /// The player's positions over the `length` seconds before `t`, oldest first and ending where they are at `t`.
    /// Never reaches before the move starts; samples where they stood still are merged, so a player who hasn't
    /// moved has a one-point trail (nothing to draw). Empty for an unknown token.
    static func points(of tokenID: String, at t: Double, in tactic: Tactic) -> [Point] {
        guard tactic.tokens.contains(where: { $0.id == tokenID }) else { return [] }
        var points: [Point] = []
        for i in 0..<samples {
            let back = length * Double(samples - 1 - i) / Double(samples - 1)
            guard let p = Timeline.state(at: max(t - back, 0), in: tactic).positions[tokenID] else { continue }
            if points.last != p { points.append(p) }
        }
        return points
    }
}
