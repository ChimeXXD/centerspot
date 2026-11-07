import Foundation

/// The move as a pure function of time (D-06, SPEC §3). Playback, scrubbing, export and tests all call
/// `state(at:in:)`, so what plays is what exports. No clock, no stored state, no randomness.
///
/// Each step but the last takes `hold` (tokens still, arrows fading in) and then its `duration`
/// (tokens move to the next step). The last step takes a final `hold`.
enum Timeline {
    /// Seconds each step rests before its move.
    static let hold = 0.3
    /// Arrows and marks fade in over this long at the start of their step and fade out over this long as its move ends.
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
                let (positions, carry) = positions(of: tactic, steps: steps[...index], to: next, progress: progress)
                return BoardState(
                    positions: positions,
                    arrows: opacity > 0 ? step.arrows.map { .init(arrow: $0, opacity: opacity) } : [],
                    stepIndex: index,
                    marks: visibleMarks(of: steps, index: index, sinceStart: time - start, progress: progress,
                                        untilEnd: end - time),
                    carry: carry
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
    ) -> (positions: [String: Point], carry: [String: Double]) {
        guard let step = steps.last else { return ([:], [:]) }
        var positions: [String: Point] = [:]
        var froms: [String: Point] = [:], tos: [String: Point] = [:]
        for token in tactic.tokens {
            let from = steps.reversed().lazy.compactMap { $0.positions[token.id] }.first ?? .centre
            froms[token.id] = from
            tos[token.id] = next?.positions[token.id] ?? from
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
        if let progress { carryBalls(in: tactic, step: step, from: froms, to: tos, progress: progress, into: &positions) }
        return (positions, carryWeights(in: tactic, from: froms, to: tos, progress: progress))
    }

    /// Each ball's `Possession.carryWeight` at this step and the next, eased between with the move. At rest it is
    /// the weight the editor draws from distance, so starting or pausing playback never moves the ball.
    static func carryWeights(in tactic: Tactic, from: [String: Point], to: [String: Point],
                             progress: Double?) -> [String: Double] {
        let aspect = tactic.pitch.kind.size.length / tactic.pitch.kind.size.width
        func carried(_ id: String, _ positions: [String: Point]) -> Double {
            guard let p = positions[id] else { return 0 }
            return Possession.carryWeight(ofBallAt: p, positions: positions, tokens: tactic.tokens, aspect: aspect)
        }
        var weights: [String: Double] = [:]
        for ball in tactic.tokens where ball.kind == .ball {
            let start = carried(ball.id, from)
            weights[ball.id] = progress.map { start + (carried(ball.id, to) - start) * $0 } ?? start
        }
        return weights
    }

    /// A ball the same player has at both ends of a move, with no run of its own, rides along that player's run at
    /// their feet instead of cutting its own straight line (Chime's recording, 7 Nov). A pass changes the carrier,
    /// so a passed ball still travels on its own.
    private static func carryBalls(in tactic: Tactic, step: Step, from: [String: Point], to: [String: Point],
                                   progress: Double, into positions: inout [String: Point]) {
        let aspect = tactic.pitch.kind.size.length / tactic.pitch.kind.size.width
        // A run of under two points is ignored in `positions`, so it doesn't count as the ball's own here either.
        for ball in tactic.tokens where ball.kind == .ball && (step.runs[ball.id]?.points.count ?? 0) < 2 {
            guard let ballFrom = from[ball.id], let ballTo = to[ball.id],
                  let carrier = Possession.carrier(ofBallAt: ballFrom, positions: from, tokens: tactic.tokens, aspect: aspect),
                  carrier == Possession.carrier(ofBallAt: ballTo, positions: to, tokens: tactic.tokens, aspect: aspect),
                  let carrierFrom = from[carrier], let carrierTo = to[carrier], let carrierNow = positions[carrier]
            else { continue }
            // The spot at their feet, eased from where it starts to where it ends.
            let dx = (ballFrom.x - carrierFrom.x) * (1 - progress) + (ballTo.x - carrierTo.x) * progress
            let dy = (ballFrom.y - carrierFrom.y) * (1 - progress) + (ballTo.y - carrierTo.y) * progress
            positions[ball.id] = Point(x: (carrierNow.x + dx).clamped(to: 0...1), y: (carrierNow.y + dy).clamped(to: 0...1))
        }
    }
}
