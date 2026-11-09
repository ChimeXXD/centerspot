import Foundation

/// Football words for a drawn arrow (D-72): the bend dot's VoiceOver label ("Bend of 3's run. Drag to change the
/// curve.") and the iPad draw row's ("3's run · drag the dot to bend"). An arrow belongs to the player it starts on
/// (strokes from a player start on them, D-59); their players read "their" first, so sides are never told apart by
/// colour alone (D-15). An arrow from the grass or the ball is "the run".
extension Placement {
    static func bendLabel(forArrow index: Int, in tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> String? {
        guard let (owner, kind) = words(forArrow: index, in: tactic, stepIndex: stepIndex, phaseIndex: phaseIndex) else {
            return nil
        }
        return "Bend of \(owner.map { "\($0) " } ?? "the ")\(kind). Drag to change the curve."
    }

    static func rowLabel(forArrow index: Int, in tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> String? {
        guard let (owner, kind) = words(forArrow: index, in: tactic, stepIndex: stepIndex, phaseIndex: phaseIndex) else {
            return nil
        }
        let what = owner.map { "\($0) \(kind)" } ?? kind.prefix(1).uppercased() + kind.dropFirst()
        return "\(what) · drag the dot to bend"
    }

    /// "3's" (or "their 5's", "Ade's") when a player stands where the arrow starts, and the kind ("run").
    private static func words(forArrow index: Int, in tactic: Tactic, stepIndex: Int,
                              phaseIndex: Int) -> (owner: String?, kind: String)? {
        guard tactic.phases.indices.contains(phaseIndex), tactic.phases[phaseIndex].steps.indices.contains(stepIndex),
              tactic.phases[phaseIndex].steps[stepIndex].arrows.indices.contains(index) else { return nil }
        let arrow = tactic.phases[phaseIndex].steps[stepIndex].arrows[index]
        let positions = Timeline.restingState(step: stepIndex, in: tactic, phaseIndex: phaseIndex).positions
        let player = tactic.tokens.first { $0.kind == .player && positions[$0.id] == arrow.points.first }
        let owner = player.flatMap { token -> String? in
            guard let who = token.number.map(String.init) ?? token.name else { return nil }
            return "\(token.side == .away ? "their " : "")\(who)'s"
        }
        return (owner, arrow.kind.rawValue)
    }
}
