import Foundation

/// Every edit the board makes, as a pure function on `inout Tactic` (SPEC §6, §9 Editing). The view applies these
/// through the document binding and registers undo; tests call them directly. Each keeps the file valid under
/// docs/FORMAT.md, so a save always reopens.
enum TacticEdits {
    /// What "+ Add" puts on the board (D-55).
    enum NewToken: Sendable, CaseIterable {
        case ourPlayer, theirPlayer, ball, cone
    }

    // MARK: Positions and steps

    /// Moves a token in one step, clamped to the pitch (D-05). Unknown tokens and steps are ignored.
    static func moveToken(_ id: String, to point: Point, step: Int, in tactic: inout Tactic, phase: Int = 0) {
        guard tactic.tokens.contains(where: { $0.id == id }), isValid(step: step, phase: phase, in: tactic) else { return }
        tactic.phases[phase].steps[step].positions[id] = point.clamped
    }

    /// Inserts a copy of step `index` after it and returns the new step's index, or nil at the 40-step cap.
    /// The copy holds every token's resolved position. It takes the original's runs, so the move to the old next
    /// step still plays from the copy; arrows and the note stay on the original.
    @discardableResult
    static func addStep(after index: Int, in tactic: inout Tactic, phase: Int = 0) -> Int? {
        guard isValid(step: index, phase: phase, in: tactic),
              tactic.phases[phase].steps.count < Phase.stepCountRange.upperBound else { return nil }
        let steps = tactic.phases[phase].steps
        let positions = Timeline.restingState(step: index, in: tactic, phaseIndex: phase).positions
        let taken = Set(tactic.phases.flatMap(\.steps).map(\.id))
        let id = (1...).lazy.map { "s\($0)" }.first { !taken.contains($0) }!
        let copy = Step(id: id, duration: steps[index].duration, positions: positions, runs: steps[index].runs)
        tactic.phases[phase].steps[index].runs = [:]
        tactic.phases[phase].steps.insert(copy, at: index + 1)
        dropRunsOnLastStep(in: &tactic, phase: phase)
        return index + 1
    }

    /// Removes a step; the last remaining step can't be deleted. Returns whether it was removed.
    @discardableResult
    static func deleteStep(at index: Int, in tactic: inout Tactic, phase: Int = 0) -> Bool {
        guard isValid(step: index, phase: phase, in: tactic), tactic.phases[phase].steps.count > 1 else { return false }
        tactic.phases[phase].steps.remove(at: index)
        dropRunsOnLastStep(in: &tactic, phase: phase)
        return true
    }

    /// Moves the step at `from` so it ends up at index `to`. Out-of-range indices are ignored.
    static func moveStep(from: Int, to: Int, in tactic: inout Tactic, phase: Int = 0) {
        guard isValid(step: from, phase: phase, in: tactic), isValid(step: to, phase: phase, in: tactic), from != to else { return }
        let step = tactic.phases[phase].steps.remove(at: from)
        tactic.phases[phase].steps.insert(step, at: to)
        dropRunsOnLastStep(in: &tactic, phase: phase)
    }

    /// Seconds for the move to the next step, clamped to 0.3…5; NaN resets to the default.
    static func setDuration(_ seconds: Double, step: Int, in tactic: inout Tactic, phase: Int = 0) {
        guard isValid(step: step, phase: phase, in: tactic) else { return }
        tactic.phases[phase].steps[step].duration = seconds.isNaN ? Step.defaultDuration : seconds.clamped(to: Step.durationRange)
    }

    /// Trimmed and cut to 140 characters; an empty note is removed.
    static func setNote(_ note: String?, step: Int, in tactic: inout Tactic, phase: Int = 0) {
        guard isValid(step: step, phase: phase, in: tactic) else { return }
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        tactic.phases[phase].steps[step].note = trimmed.isEmpty ? nil : String(trimmed.prefix(Step.maxNoteLength))
    }

    static func setPitch(kind: Pitch.Kind, style: Pitch.Style, in tactic: inout Tactic) {
        tactic.pitch = Pitch(kind: kind, style: style)
    }

    // MARK: Tokens

    /// Adds a token on the centre spot in every step and returns its id, or nil at the 30-token cap or when a ball
    /// is already on the board (D-55). Players take the lowest shirt number their side isn't using.
    @discardableResult
    static func addToken(_ kind: NewToken, in tactic: inout Tactic) -> String? {
        guard tactic.tokens.count < TacticFormat.maxTokens else { return nil }
        let token: Token
        switch kind {
        case .ourPlayer, .theirPlayer:
            let side: Side.ID = kind == .ourPlayer ? .home : .away
            let used = Set(tactic.tokens.filter { $0.kind == .player && $0.side == side }.compactMap(\.number))
            let number = Token.numberRange.lazy.dropFirst().first { !used.contains($0) }
            let base = (side == .home ? "h" : "a") + (number.map(String.init) ?? "")
            token = Token(id: unusedID(base, in: tactic), kind: .player, side: side, number: number)
        case .ball:
            guard !tactic.tokens.contains(where: { $0.kind == .ball }) else { return nil }
            token = Token(id: unusedID("ball", in: tactic), kind: .ball)
        case .cone:
            token = Token(id: unusedID("cone", in: tactic), kind: .cone)
        }
        tactic.tokens.append(token)
        for p in tactic.phases.indices {
            for s in tactic.phases[p].steps.indices { tactic.phases[p].steps[s].positions[token.id] = .centre }
        }
        return token.id
    }

    /// Removes a token with its positions and runs in every step.
    static func deleteToken(_ id: String, in tactic: inout Tactic) {
        tactic.tokens.removeAll { $0.id == id }
        for p in tactic.phases.indices {
            for s in tactic.phases[p].steps.indices {
                tactic.phases[p].steps[s].positions[id] = nil
                tactic.phases[p].steps[s].runs[id] = nil
            }
        }
    }

    /// Trimmed and cut to 24 characters; an empty name is removed.
    static func setName(_ name: String?, token id: String, in tactic: inout Tactic) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        update(id, in: &tactic) { $0.name = trimmed.isEmpty ? nil : String(trimmed.prefix(Token.maxNameLength)) }
    }

    /// Clamped to 0…99; nil removes the number.
    static func setNumber(_ number: Int?, token id: String, in tactic: inout Tactic) {
        update(id, in: &tactic) { $0.number = number?.clamped(to: Token.numberRange) }
    }

    static func setRole(_ roleID: String?, token id: String, in tactic: inout Tactic) {
        update(id, in: &tactic) { $0.roleID = roleID }
    }

    /// Only players have a side.
    static func setSide(_ side: Side.ID, token id: String, in tactic: inout Tactic) {
        update(id, in: &tactic) { if $0.kind == .player { $0.side = side } }
    }

    // MARK: Helpers

    private static func isValid(step: Int, phase: Int, in tactic: Tactic) -> Bool {
        tactic.phases.indices.contains(phase) && tactic.phases[phase].steps.indices.contains(step)
    }

    private static func update(_ id: String, in tactic: inout Tactic, _ change: (inout Token) -> Void) {
        guard let i = tactic.tokens.firstIndex(where: { $0.id == id }) else { return }
        change(&tactic.tokens[i])
    }

    /// A run on the last step has no next step to end at (docs/FORMAT.md drops it on read), so edits drop it too.
    private static func dropRunsOnLastStep(in tactic: inout Tactic, phase: Int) {
        guard let last = tactic.phases[phase].steps.indices.last else { return }
        tactic.phases[phase].steps[last].runs = [:]
    }

    private static func unusedID(_ base: String, in tactic: Tactic) -> String {
        let taken = Set(tactic.tokens.map(\.id))
        if !taken.contains(base) { return base }
        return (2...).lazy.map { "\(base)-\($0)" }.first { !taken.contains($0) }!
    }
}
