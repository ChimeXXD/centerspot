import Foundation

/// A preset shape from `presets/formations.json` (D-14): one slot per player, in normalised coordinates (D-05).
struct Formation: Codable, Sendable, Hashable, Identifiable {
    struct Slot: Codable, Sendable, Hashable {
        let number: Int
        let roleID: String
        let point: Point

        private enum CodingKeys: String, CodingKey { case number, roleID, x, y }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            number = try c.decode(Int.self, forKey: .number)
            roleID = try c.decode(String.self, forKey: .roleID)
            point = Point(x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y)).clamped
        }

        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(number, forKey: .number)
            try c.encode(roleID, forKey: .roleID)
            try c.encode(point.x, forKey: .x)
            try c.encode(point.y, forKey: .y)
        }
    }

    let id: String
    let name: String
    let pitch: Pitch.Kind
    let slots: [Slot]

    /// Moves the home players into this shape in one step. Names and numbers stay (D-14); a player's role follows
    /// the slot they land on. Players match slots by shirt number first, then in board order; slots left over get
    /// new players, placed in every step; players left over keep their positions. The away side and the ball stay.
    func apply(to tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> Tactic {
        guard tactic.phases.indices.contains(phaseIndex),
              tactic.phases[phaseIndex].steps.indices.contains(stepIndex) else { return tactic }
        var result = tactic
        result.pitch.kind = pitch

        let home = result.tokens.indices.filter { result.tokens[$0].kind == .player && result.tokens[$0].side == .home }
        var free = slots
        var placed: [(token: Int, slot: Slot)] = []
        for i in home {
            if let number = result.tokens[i].number, let k = free.firstIndex(where: { $0.number == number }) {
                placed.append((i, free.remove(at: k)))
            }
        }
        for i in home where !placed.contains(where: { $0.token == i }) {
            guard !free.isEmpty else { break }
            placed.append((i, free.removeFirst()))
        }
        for (i, slot) in placed {
            result.tokens[i].roleID = slot.roleID
            result.phases[phaseIndex].steps[stepIndex].positions[result.tokens[i].id] = slot.point
        }

        for slot in free where result.tokens.count < TacticFormat.maxTokens {
            let id = Self.unusedID(base: "h\(slot.number)", in: result.tokens)
            result.tokens.append(Token(id: id, kind: .player, side: .home, number: slot.number, roleID: slot.roleID))
            for p in result.phases.indices {
                for s in result.phases[p].steps.indices { result.phases[p].steps[s].positions[id] = slot.point }
            }
        }
        return result
    }

    private static func unusedID(base: String, in tokens: [Token]) -> String {
        let taken = Set(tokens.map(\.id))
        if !taken.contains(base) { return base }
        return (2...).lazy.map { "\(base)-\($0)" }.first { !taken.contains($0) }!
    }
}
