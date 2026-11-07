import Foundation

/// The draw tools' marks (D-65) as pure edits on `inout Tactic`, like `TacticEdits`: zones, shape lines, rings and heat
/// on one step. Each keeps the file valid under docs/FORMAT.md (at most 12 marks a step, lines of one side, zones inside
/// the pitch), so a save always reopens unchanged. New ids are unused in the whole tactic, so two separate marks never
/// ease into each other; `TacticEdits.addStep` copies a step's marks with their ids, so those do.
enum MarkEdits {
    /// What an add did.
    enum Result: Equatable, Sendable {
        case added(String)
        /// Rings were already on that player: nothing changed; select this one instead.
        case existing(String)
        /// A box under 4% of the pitch on either side is a tap, not a zone.
        case tooSmall
        /// The step already has 12 marks.
        case full
        /// Nothing to add: not a player, fewer than two players, or no such step.
        case invalid
    }

    /// A zone's corner as it looks on screen: top is toward the opponent's goal (y = 1, D-05).
    enum Corner: String, CaseIterable, Sendable {
        case topLeft = "tl", topRight = "tr", bottomLeft = "bl", bottomRight = "br"
    }

    // MARK: Adding

    /// A zone from one corner of a drag to the other, clamped to the pitch.
    static func addZone(from a: Point, to b: Point, step: Int, in tactic: inout Tactic, phase: Int = 0) -> Result {
        guard isValid(step: step, phase: phase, in: tactic) else { return .invalid }
        let a = a.clamped, b = b.clamped
        guard abs(b.x - a.x) >= Zone.minSize, abs(b.y - a.y) >= Zone.minSize else { return .tooSmall }
        guard hasRoom(step: step, phase: phase, in: tactic) else { return .full }
        let id = unusedID("z", in: tactic)
        tactic.phases[phase].steps[step].marks.zones.append(Zone(id: id, from: a, to: b))
        return .added(id)
    }

    /// A line joining `tokens` in order: players of the first one's side, each once; two at least.
    static func addLine(_ tokens: [String], step: Int, in tactic: inout Tactic, phase: Int = 0) -> Result {
        guard isValid(step: step, phase: phase, in: tactic) else { return .invalid }
        let id = unusedID("l", in: tactic)
        let line = ShapeLine(id: id, tokens: Array(tokens.prefix(ShapeLine.maxTokens)))
        guard let kept = TacticFormat.repairedMarks(Marks(lines: [line]), tokens: tactic.tokens).lines.first else { return .invalid }
        guard hasRoom(step: step, phase: phase, in: tactic) else { return .full }
        tactic.phases[phase].steps[step].marks.lines.append(kept)
        return .added(id)
    }

    /// Rings under a player. A player who already has them on this step is left alone (`existing`).
    static func addRings(on token: String, step: Int, in tactic: inout Tactic, phase: Int = 0) -> Result {
        guard isValid(step: step, phase: phase, in: tactic),
              tactic.tokens.contains(where: { $0.id == token && $0.kind == .player }) else { return .invalid }
        if let glow = tactic.phases[phase].steps[step].marks.glows.first(where: { $0.tokenID == token }) {
            return .existing(glow.id)
        }
        guard hasRoom(step: step, phase: phase, in: tactic) else { return .full }
        let id = unusedID("g", in: tactic)
        tactic.phases[phase].steps[step].marks.glows.append(Glow(id: id, target: .token(token)))
        return .added(id)
    }

    /// Heat centred on a spot of the grass, at the default size.
    static func addHeat(at p: Point, step: Int, in tactic: inout Tactic, phase: Int = 0) -> Result {
        guard isValid(step: step, phase: phase, in: tactic) else { return .invalid }
        guard hasRoom(step: step, phase: phase, in: tactic) else { return .full }
        let id = unusedID("g", in: tactic)
        tactic.phases[phase].steps[step].marks.glows.append(Glow(id: id, target: .spot(p.clamped, radius: Glow.defaultRadius)))
        return .added(id)
    }

    // MARK: Changing

    /// Moves a zone by `dx`, `dy` (pitch units), keeping its size; it stops at the touchlines and goal lines.
    static func moveZone(_ id: String, by dx: Double, _ dy: Double, step: Int, in tactic: inout Tactic, phase: Int = 0) {
        updateZone(id, step: step, phase: phase, in: &tactic) { zone in
            guard dx.isFinite, dy.isFinite else { return }
            zone.x = (zone.x + dx).clamped(to: 0...max(0, 1 - zone.w))
            zone.y = (zone.y + dy).clamped(to: 0...max(0, 1 - zone.h))
        }
    }

    /// Drags one corner to `p`; the opposite corner stays put, and the zone stays at least 4% each side.
    static func resizeZone(_ id: String, corner: Corner, to p: Point, step: Int, in tactic: inout Tactic, phase: Int = 0) {
        updateZone(id, step: step, phase: phase, in: &tactic) { zone in
            let p = p.clamped
            var (left, right, bottom, top) = (zone.x, zone.x + zone.w, zone.y, zone.y + zone.h)
            switch corner {
            case .topLeft, .bottomLeft: left = min(p.x, right - Zone.minSize)
            case .topRight, .bottomRight: right = max(p.x, left + Zone.minSize)
            }
            switch corner {
            case .bottomLeft, .bottomRight: bottom = min(p.y, top - Zone.minSize)
            case .topLeft, .topRight: top = max(p.y, bottom + Zone.minSize)
            }
            zone = Zone(id: zone.id, x: left, y: bottom, w: right - left, h: top - bottom, colour: zone.colour).clamped
        }
    }

    /// Removes the mark with `id` from one step. Returns whether there was one.
    @discardableResult
    static func remove(_ id: String, step: Int, in tactic: inout Tactic, phase: Int = 0) -> Bool {
        guard isValid(step: step, phase: phase, in: tactic) else { return false }
        let before = tactic.phases[phase].steps[step].marks.count
        tactic.phases[phase].steps[step].marks.zones.removeAll { $0.id == id }
        tactic.phases[phase].steps[step].marks.lines.removeAll { $0.id == id }
        tactic.phases[phase].steps[step].marks.glows.removeAll { $0.id == id }
        return tactic.phases[phase].steps[step].marks.count < before
    }

    // MARK: Helpers

    private static func isValid(step: Int, phase: Int, in tactic: Tactic) -> Bool {
        tactic.phases.indices.contains(phase) && tactic.phases[phase].steps.indices.contains(step)
    }

    private static func hasRoom(step: Int, phase: Int, in tactic: Tactic) -> Bool {
        tactic.phases[phase].steps[step].marks.count < Marks.maxCount
    }

    private static func updateZone(_ id: String, step: Int, phase: Int, in tactic: inout Tactic, _ change: (inout Zone) -> Void) {
        guard isValid(step: step, phase: phase, in: tactic),
              let i = tactic.phases[phase].steps[step].marks.zones.firstIndex(where: { $0.id == id }) else { return }
        change(&tactic.phases[phase].steps[step].marks.zones[i])
    }

    /// `z1`, `l2`, `g3`: the first number no mark in any step uses with that prefix.
    static func unusedID(_ prefix: String, in tactic: Tactic) -> String {
        let taken = Set(tactic.phases.flatMap(\.steps).flatMap(\.marks.ids))
        return (1...).lazy.map { "\(prefix)\($0)" }.first { !taken.contains($0) }!
    }
}
