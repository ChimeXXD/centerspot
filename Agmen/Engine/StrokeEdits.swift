import Foundation

/// What a stroke drawn on a step does to the tactic (D4-2, D-59), as a pure edit like `TacticEdits`. The picked kind
/// decides what moves: Run the player, Pass the ball, Dribble both, Press the player; a stroke from the grass (or a
/// cone) moves nothing. Every stroke also leaves an arrow of its kind on the step, so the paused board shows the plan
/// (D-46). The stroke is simplified (D-08) and then takes the picked shape (D-72: straight, or one fitted bend); a
/// mover's run follows that line and its next-step position moves to its end, adding a step when there is none (D-28).
/// Runs stay anchored (D-27), so the result reopens unchanged.
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

    /// Shorter strokes are taps, in pitch widths (about 7 pt on a 345 pt pitch).
    static let minimumLength = 0.02

    /// Draws `stroke` (normalised points, as captured) on step `step`, starting on `tokenID` (nil: the grass), as the
    /// picked `shape` (D-72; Straight unless the Draw panel says otherwise).
    @discardableResult
    static func draw(_ stroke: [Point], kind: Arrow.Kind, shape: ArrowShape = .straight, from tokenID: String?, step: Int,
                     in tactic: inout Tactic, phase: Int = 0) -> Outcome {
        guard tactic.phases.indices.contains(phase), tactic.phases[phase].steps.indices.contains(step) else { return .init() }
        let aspect = pitchAspect(of: tactic)
        var line = PathSimplifier.simplify(stroke.map(\.clamped), aspect: aspect)
        guard length(of: line, aspect: aspect) >= minimumLength else { return .init() }

        let token = tactic.tokens.first { $0.id == tokenID }
        let here = Timeline.restingState(step: step, in: tactic, phaseIndex: phase).positions
        // An arrow from a player or the ball starts on them, so redrawing one can find and replace it.
        if let token, token.kind == .player || token.kind == .ball, let start = here[token.id] {
            line[0] = start
        }
        line = ShapedPath.path(for: line, shape: shape, aspect: aspect)
        // It has to end somewhere else: from the disc's edge back to its centre, or a loop back to where it started,
        // is long enough as drawn but goes nowhere.
        guard length(of: [line[0], line[line.count - 1]], aspect: aspect) >= minimumLength else { return .init() }

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

    /// Moves the middle dot of arrow `index` on step `step` to `dot` (D-72), keeping its ends, and bends the runs that
    /// follow it the same way, each keeping its own ends (the mover starts where they stand, D-59, and may since have
    /// been given another spot in the next step). A run follows the arrow when its points between the ends are the
    /// arrow's, or, for a straight arrow, when it ends where the arrow does and is the arrow's own mover (starts where
    /// it starts) or the ball. Returns whether anything changed.
    @discardableResult
    static func bend(arrow index: Int, to dot: Point, step: Int, in tactic: inout Tactic, phase: Int = 0) -> Bool {
        guard tactic.phases.indices.contains(phase), tactic.phases[phase].steps.indices.contains(step),
              tactic.phases[phase].steps[step].arrows.indices.contains(index) else { return false }
        let before = tactic.phases[phase].steps[step]
        let old = before.arrows[index].points
        let new = ShapedPath.nudged(old, dotTo: dot, aspect: pitchAspect(of: tactic))
        guard new != old else { return false }
        var after = before
        after.arrows[index].points = new
        let ball = tactic.tokens.first { $0.kind == .ball }?.id
        for (id, run) in before.runs where follows(run.points, old, isBall: id == ball) {
            let inside = Array(new.dropFirst().dropLast())
            after.runs[id] = Path(points: [run.points[0]] + inside + [run.points[run.points.count - 1]])
        }
        tactic.phases[phase].steps[step] = after
        return true
    }

    /// Who follows a stroke of `kind` that starts on `token` (D-59). A loose ball follows any stroke but a press. A
    /// pass or dribble moves the ball only when the player has it at their feet; otherwise the ball stays.
    static func movers(of kind: Arrow.Kind, from token: Token?, in tactic: Tactic,
                       positions: [String: Point], aspect: Double) -> [String] {
        guard let token else { return [] }
        let ball = tactic.tokens.first { $0.kind == .ball }.map { [$0.id] } ?? []
        let carried = ball.filter { has($0, token.id, in: tactic, positions: positions, aspect: aspect) }
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

    /// Whether `player` has `ball` at their feet: the nearest player in reach (`Possession.carrier`), the same rule
    /// the timeline uses to carry the ball.
    private static func has(_ ball: String, _ player: String, in tactic: Tactic, positions: [String: Point],
                            aspect: Double) -> Bool {
        guard let b = positions[ball] else { return false }
        return Possession.carrier(ofBallAt: b, positions: positions, tokens: tactic.tokens, aspect: aspect) == player
    }

    /// A straight run has no points of its own to match, so ending together isn't enough: another player's straight
    /// run to the same spot (two strokes clamped to a corner) must not bend with this arrow.
    private static func follows(_ run: [Point], _ arrow: [Point], isBall: Bool) -> Bool {
        guard run.count == arrow.count, run.count >= 2 else { return false }
        if run.count == 2 { return run[1] == arrow[1] && (isBall || run[0] == arrow[0]) }
        return run.dropFirst().dropLast() == arrow.dropFirst().dropLast()
    }

    private static func pitchAspect(of tactic: Tactic) -> Double {
        tactic.pitch.kind.size.length / tactic.pitch.kind.size.width
    }

    /// Length in pitch widths, measured as it looks on the pitch.
    private static func length(of points: [Point], aspect: Double) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, ($1.1.y - $1.0.y) * aspect) }
    }
}
