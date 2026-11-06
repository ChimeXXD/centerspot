import Foundation

/// The move as a pure function of time (D-06, SPEC §3). Playback, scrubbing, export and tests all call
/// `state(at:in:)`, so what plays is what exports. No clock, no stored state, no randomness.
///
/// Each step but the last takes `hold` (tokens still, arrows fading in) and then its `duration`
/// (tokens move to the next step). The last step takes a final `hold`.
enum Timeline {
    /// Seconds each step rests before its move.
    static let hold = 0.3
    /// Arrows fade in over this long at the start of their step and fade out over this long as its move ends.
    static let arrowFade = 0.2

    /// Σ (hold + step.duration) over all steps but the last, plus a final hold. 0 for no steps.
    static func duration(of phase: Phase) -> Double {
        guard !phase.steps.isEmpty else { return 0 }
        return phase.steps.dropLast().reduce(hold) { $0 + hold + $1.duration }
    }

    /// The board at time `t` (seconds, clamped to `0…duration`; NaN reads as 0) in the given phase.
    static func state(at t: Double, in tactic: Tactic, phaseIndex: Int = 0) -> BoardState {
        guard tactic.phases.indices.contains(phaseIndex) else {
            return BoardState(positions: [:], arrows: [], stepIndex: 0)
        }
        let phase = tactic.phases[phaseIndex]
        let steps = phase.steps
        let time = t.isNaN ? 0 : min(max(t, 0), duration(of: phase))

        var start = 0.0
        for (index, step) in steps.enumerated() {
            let moveStart = start + hold
            let isLast = index == steps.count - 1
            let end = isLast ? moveStart : moveStart + step.duration
            if isLast || time < end {
                let next = isLast ? nil : steps[index + 1]
                let progress = time < moveStart || next == nil
                    ? nil
                    : Easing.inOutCubic(step.duration > 0 ? (time - moveStart) / step.duration : 1)
                let opacity = time < moveStart || isLast
                    ? min(1, (time - start) / arrowFade)
                    : min(1, (end - time) / arrowFade)
                return BoardState(
                    positions: positions(of: tactic, steps: steps[...index], to: next, progress: progress),
                    arrows: opacity > 0 ? step.arrows.map { .init(arrow: $0, opacity: opacity) } : [],
                    stepIndex: index
                )
            }
            start = end
        }
        return BoardState(positions: [:], arrows: [], stepIndex: 0)
    }

    /// Token positions between the last of `steps` and `next` at eased `progress`; `nil` progress means
    /// holding still. A token missing from a step keeps its position from the step before, else the
    /// centre spot (the same rule as import, docs/FORMAT.md), so an unrepaired tactic never jumps.
    private static func positions(
        of tactic: Tactic,
        steps: ArraySlice<Step>,
        to next: Step?,
        progress: Double?
    ) -> [String: Point] {
        guard let step = steps.last else { return [:] }
        var positions: [String: Point] = [:]
        for token in tactic.tokens {
            let from = steps.reversed().lazy.compactMap { $0.positions[token.id] }.first ?? .centre
            guard let progress, let to = next?.positions[token.id] else {
                positions[token.id] = from  // holding, or missing from the next step: stays where it was
                continue
            }
            if let run = step.runs[token.id], run.points.count >= 2 {
                // Anchor here too (D-27), so a run left stale by an edit can't make the token jump.
                var points = run.points
                points[0] = from
                points[points.count - 1] = to
                positions[token.id] = PathSampler.point(at: progress, along: points, on: tactic.pitch.kind)
            } else {
                positions[token.id] = Point(x: from.x + (to.x - from.x) * progress,
                                            y: from.y + (to.y - from.y) * progress)
            }
        }
        return positions
    }
}
