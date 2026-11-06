import Foundation

/// The refuse and repair rules from docs/FORMAT.md's Rules table (D-27), applied after JSON decoding.
/// Per-value rules that decoding already enforces: coordinates are finite and clamped (`Point`), enum
/// values are known (`Pitch.Kind`, `Token.Kind`, `Phase.ID`, `Arrow.Kind`, `Side.ID`), and an unknown
/// colour or pitch style falls back to a default (`Side`, `Pitch`).
extension TacticFormat {
    static func validated(
        _ input: Tactic,
        knownRoleIDs: Set<String>?
    ) throws(TacticFormatError) -> Tactic {
        var tactic = input
        tactic.sides = try validatedSides(tactic.sides)
        tactic.tokens = try validatedTokens(tactic.tokens, knownRoleIDs: knownRoleIDs)

        guard Phase.countRange.contains(tactic.phases.count),
              Set(tactic.phases.map(\.id)).count == tactic.phases.count
        else { throw .unreadable }

        let tokenIDs = tactic.tokens.map(\.id)
        for index in tactic.phases.indices {
            tactic.phases[index].steps = try validatedSteps(tactic.phases[index].steps, tokenIDs: tokenIDs)
        }
        return tactic
    }

    /// Exactly one home and one away side, returned in that order.
    private static func validatedSides(_ sides: [Side]) throws(TacticFormatError) -> [Side] {
        guard sides.count == 2,
              let home = sides.first(where: { $0.id == .home }),
              let away = sides.first(where: { $0.id == .away })
        else { throw .unreadable }
        return [home, away]
    }

    private static func validatedTokens(
        _ tokens: [Token],
        knownRoleIDs: Set<String>?
    ) throws(TacticFormatError) -> [Token] {
        guard tokens.count <= maxTokens,
              Set(tokens.map(\.id)).count == tokens.count,
              tokens.allSatisfy({ $0.kind != .player || $0.side != nil })
        else { throw .unreadable }

        return tokens.map { token in
            var token = token
            token.number = token.number.map { $0.clamped(to: Token.numberRange) }
            token.name = token.name.map { String($0.prefix(Token.maxNameLength)) }
            if let roleID = token.roleID, let knownRoleIDs, !knownRoleIDs.contains(roleID) {
                token.roleID = nil
            }
            return token
        }
    }

    private static func validatedSteps(
        _ input: [Step],
        tokenIDs: [String]
    ) throws(TacticFormatError) -> [Step] {
        guard Phase.stepCountRange.contains(input.count),
              Set(input.map(\.id)).count == input.count
        else { throw .unreadable }

        // Structure and safety first: every limit refuses, even on a run that would later be dropped.
        for step in input {
            guard step.duration.isFinite,
                  step.arrows.count <= Step.maxArrows,
                  step.arrows.allSatisfy({ Path.pointCountRange.contains($0.points.count) }),
                  step.runs.values.allSatisfy({ Path.pointCountRange.contains($0.points.count) })
            else { throw .unreadable }
        }

        var steps = input
        var previous: [String: Point] = [:]
        for index in steps.indices {
            steps[index].duration = steps[index].duration.clamped(to: Step.durationRange)
            steps[index].note = steps[index].note.map { String($0.prefix(Step.maxNoteLength)) }

            // Every token gets a position: its own, else the step before's, else the centre spot.
            // Keys that name no token are dropped.
            let written = steps[index].positions
            var positions: [String: Point] = [:]
            for id in tokenIDs {
                positions[id] = written[id] ?? previous[id] ?? .centre
            }
            steps[index].positions = positions
            previous = positions
        }

        // Anchor runs once every step's positions are known (D-27); a run on the last step is dropped.
        for index in steps.indices {
            guard index + 1 < steps.count else {
                steps[index].runs = [:]
                continue
            }
            let here = steps[index].positions
            let next = steps[index + 1].positions
            var runs: [String: Path] = [:]
            for (id, run) in steps[index].runs {
                guard let start = here[id], let end = next[id] else { continue }  // unknown token: drop
                var anchored = run
                anchored.points[0] = start
                anchored.points[anchored.points.count - 1] = end
                runs[id] = anchored
            }
            steps[index].runs = runs
        }
        return steps
    }
}
