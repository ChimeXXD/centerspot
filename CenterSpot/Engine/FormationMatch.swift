import Foundation

/// Names the shape the home side starts in, for the tag under the pitch ("4-3-3"). A formation matches when the
/// pitch kind and player count agree and every home player in the step on screen stands within `tolerance` of a slot, matched by
/// shirt number first, then to the nearest free slot.
enum FormationMatch {
    /// How far (normalised) a player may stand from their slot and still count as in shape.
    static let tolerance = 0.04

    static func formation(of tactic: Tactic, in formations: [Formation], step: Int = 0, phaseIndex: Int = 0) -> Formation? {
        let state = Timeline.restingState(step: step, in: tactic, phaseIndex: phaseIndex)
        let players = tactic.tokens.filter { $0.kind == .player && $0.side == .home }
        guard !players.isEmpty else { return nil }
        var best: (formation: Formation, worst: Double)?
        for formation in formations where formation.pitch == tactic.pitch.kind && formation.slots.count == players.count {
            guard let worst = worstDistance(players, positions: state.positions, slots: formation.slots),
                  worst <= tolerance, worst < (best?.worst ?? .infinity) else { continue }
            best = (formation, worst)
        }
        return best?.formation
    }

    /// The largest player-to-slot distance, or nil if a player has no position.
    private static func worstDistance(_ players: [Token], positions: [String: Point], slots: [Formation.Slot]) -> Double? {
        var free = slots
        var unmatched: [Point] = []
        var worst = 0.0
        for player in players {
            guard let p = positions[player.id] else { return nil }
            if let number = player.number, let i = free.firstIndex(where: { $0.number == number }) {
                worst = max(worst, distance(p, free.remove(at: i).point))
            } else {
                unmatched.append(p)
            }
        }
        for p in unmatched {
            guard let i = free.indices.min(by: { distance(p, free[$0].point) < distance(p, free[$1].point) }) else { return nil }
            worst = max(worst, distance(p, free.remove(at: i).point))
        }
        return worst
    }

    private static func distance(_ a: Point, _ b: Point) -> Double { hypot(a.x - b.x, a.y - b.y) }
}
