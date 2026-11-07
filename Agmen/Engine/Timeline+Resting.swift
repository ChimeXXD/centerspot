import Foundation

extension Timeline {
    /// The board at rest on one step, as the editor shows it: every token where the step puts it (a token missing
    /// from the step keeps its last position, else the centre spot, the same rule as `state(at:in:)`) and the
    /// step's arrows fully shown. Equal to `state(at:)` at the end of the step's hold.
    static func restingState(step: Int, in tactic: Tactic, phaseIndex: Int = 0) -> BoardState {
        guard tactic.phases.indices.contains(phaseIndex), tactic.phases[phaseIndex].steps.indices.contains(step) else {
            return BoardState(positions: [:], arrows: [], stepIndex: 0)
        }
        let steps = tactic.phases[phaseIndex].steps[...step]
        var positions: [String: Point] = [:]
        for token in tactic.tokens {
            positions[token.id] = steps.reversed().lazy.compactMap { $0.positions[token.id] }.first ?? .centre
        }
        let arrows = tactic.phases[phaseIndex].steps[step].arrows.map { BoardState.VisibleArrow(arrow: $0, opacity: 1) }
        return BoardState(positions: positions, arrows: arrows, stepIndex: step)
    }
}
