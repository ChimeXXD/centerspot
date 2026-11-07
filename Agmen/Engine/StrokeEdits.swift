import Foundation

/// What a stroke drawn on a step does to the tactic (D4-2, D-59), as a pure edit like `TacticEdits`. The picked kind
/// decides what moves: Run the player, Pass the ball, Dribble both, Press the player; a stroke from the grass (or a
/// cone) moves nothing. Every stroke also leaves an arrow of its kind on the step, so the paused board shows the plan
/// (D-46). A mover's run follows the simplified stroke (D-08) and its next-step position moves to the stroke's end,
/// adding a step when there is none (D-28). Runs stay anchored (D-27), so the result reopens unchanged.
enum StrokeEdits {
    /// What happened, for the board's message.
    struct Outcome: Equatable, Sendable {
        var changed = false
        /// A step was added after the last one for the mover to run to (D-28).
        var addedStep = false
        /// The step already shows 30 arrows; the new one was left off.
        var hitArrowLimit = false
        /// The last step is the 40th, so nothing could run from it; only the arrow was drawn.
        var hitStepLimit = false
    }

    /// A player within this distance of the ball (pitch widths, measured as it looks) has it at their feet: 1.2 disc
    /// radii, where `BoardGeometry.drawnCentres` draws the ball at a carrier's feet, so what you see decides who passes.
    static let possessionReach = 0.038 * 1.2

    /// Shorter strokes are taps, in pitch widths (about 7 pt on a 345 pt pitch).
    static let minimumLength = 0.02

    /// Draws `stroke` (normalised points, as captured) on step `step`, starting on `tokenID` (nil: the grass).
    @discardableResult
    static func draw(_ stroke: [Point], kind: Arrow.Kind, from tokenID: String?, step: Int,
                     in tactic: inout Tactic, phase: Int = 0) -> Outcome {
        guard tactic.phases.indices.contains(phase), tactic.phases[phase].steps.indices.contains(step) else { return .init() }
        let aspect = tactic.pitch.kind.size.length / tactic.pitch.kind.size.width
        var line = PathSimplifier.simplify(stroke.map(\.clamped), aspect: aspect)
        guard length(of: line, aspect: aspect) >= minimumLength else { return .init() }

        let token = tactic.tokens.first { $0.id == tokenID }
        let here = Timeline.restingState(step: step, in: tactic, phaseIndex: phase).positions
        // An arrow from a player or the ball starts on them, so redrawing one can find and replace it.
        if let token, token.kind == .player || token.kind == .ball, let start = here[token.id] {
            line[0] = start
            // From the disc's edge back to its centre is long enough as drawn but goes nowhere once anchored.
            guard length(of: line, aspect: aspect) >= minimumLength else { return .init() }
        }

        var outcome = Outcome()
        var arrows = tactic.phases[phase].steps[step].arrows
        if token != nil { arrows.removeAll { $0.kind == kind && $0.points.first == line[0] } }
        if arrows.count < Step.maxArrows {
            arrows.append(Arrow(kind: kind, points: line))
        } else {
            outcome.hitArrowLimit = true
        }
        if arrows != tactic.phases[phase].steps[step].arrows {
            tactic.phases[phase].steps[step].arrows = arrows
            outcome.changed = true
        }

        let movers = movers(of: kind, from: token, in: tactic, positions: here, aspect: aspect)
        guard !movers.isEmpty else { return outcome }
        if step == tactic.phases[phase].steps.count - 1 {
            guard TacticEdits.addStep(after: step, in: &tactic, phase: phase) != nil else {
                outcome.hitStepLimit = true
                return outcome
            }
            outcome.addedStep = true
        }
        let end = line[line.count - 1]
        for id in movers {
            let from = here[id] ?? .centre
            var run = line
            run[0] = from
            tactic.phases[phase].steps[step].positions[id] = from
            tactic.phases[phase].steps[step].runs[id] = Path(points: run)
            tactic.phases[phase].steps[step + 1].positions[id] = end
            // The mover's own run from the next step now starts where this one ends (D-27).
            tactic.phases[phase].steps[step + 1].runs[id]?.points[0] = end
        }
        outcome.changed = true
        return outcome
    }

    /// Who follows a stroke of `kind` that starts on `token` (D-59). A loose ball follows any stroke but a press. A
    /// pass or dribble moves the ball only when the player has it at their feet; otherwise the ball stays.
    static func movers(of kind: Arrow.Kind, from token: Token?, in tactic: Tactic,
                       positions: [String: Point], aspect: Double) -> [String] {
        guard let token else { return [] }
        let ball = tactic.tokens.first { $0.kind == .ball }.map { [$0.id] } ?? []
        let carried = ball.filter { has($0, token.id, positions: positions, aspect: aspect) }
        switch token.kind {
        case .player:
            switch kind {
            case .run, .press: return [token.id]
            case .pass: return carried
            case .dribble: return [token.id] + carried
            }
        case .ball: return kind == .press ? [] : [token.id]
        case .cone, .marker: return []
        }
    }

    /// Whether `player` has `ball` at their feet (within `possessionReach`).
    private static func has(_ ball: String, _ player: String, positions: [String: Point], aspect: Double) -> Bool {
        guard let b = positions[ball], let p = positions[player] else { return false }
        return hypot(b.x - p.x, (b.y - p.y) * aspect) < possessionReach
    }

    /// Length in pitch widths, measured as it looks on the pitch.
    private static func length(of points: [Point], aspect: Double) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, ($1.1.y - $1.0.y) * aspect) }
    }
}
