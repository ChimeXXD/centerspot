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
    /// new players, placed in every step; players left over are removed, from every step and mark (D-83). The away
    /// side and the ball stay.
    func apply(to tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> Tactic {
        guard tactic.phases.indices.contains(phaseIndex),
              tactic.phases[phaseIndex].steps.indices.contains(stepIndex) else { return tactic }
        var result = tactic
        result.pitch.kind = pitch
        Self.place(slots.map { ($0.number, $0.roleID, $0.point) }, side: .home, in: &result, stepIndex: stepIndex,
                   phaseIndex: phaseIndex)
        return result
    }

    /// One side's players onto `places` (number, role, point) at one step, as `apply` does for the home side: matched
    /// by shirt number first, then in board order; names stay, roles follow the place; places left over get new
    /// players (placed in every step), players left over are removed with their arrows. Scenarios use it for both
    /// sides (D-94). Returns which token took each place, by the place's shirt number.
    @discardableResult
    static func place(_ places: [(number: Int, roleID: String, point: Point)], side: Side.ID, in result: inout Tactic,
                      stepIndex: Int, phaseIndex: Int = 0) -> [Int: String] {
        let team = result.tokens.indices.filter { result.tokens[$0].kind == .player && result.tokens[$0].side == side }
        var free = places
        var placed: [(token: Int, place: (number: Int, roleID: String, point: Point))] = []
        for i in team {
            if let number = result.tokens[i].number, let k = free.firstIndex(where: { $0.number == number }) {
                placed.append((i, free.remove(at: k)))
            }
        }
        for i in team where !placed.contains(where: { $0.token == i }) {
            guard !free.isEmpty else { break }
            placed.append((i, free.removeFirst()))
        }
        var tokenFor: [Int: String] = [:]
        for (i, place) in placed {
            result.tokens[i].roleID = place.roleID
            result.phases[phaseIndex].steps[stepIndex].positions[result.tokens[i].id] = place.point
            tokenFor[place.number] = result.tokens[i].id
        }
        let leftover = team.filter { i in !placed.contains { $0.token == i } }.map { result.tokens[$0].id }
        if !leftover.isEmpty { removeArrows(from: Set(leftover), in: &result) }
        for id in leftover { TacticEdits.deleteToken(id, in: &result) }

        let prefix = side == .home ? "h" : "a"
        for place in free where result.tokens.count < TacticFormat.maxTokens {
            let id = unusedID(base: "\(prefix)\(place.number)", in: result.tokens)
            result.tokens.append(Token(id: id, kind: .player, side: side, number: place.number, roleID: place.roleID))
            for p in result.phases.indices {
                for s in result.phases[p].steps.indices { result.phases[p].steps[s].positions[id] = place.point }
            }
            tokenFor[place.number] = id
        }
        return tokenFor
    }

    /// How many home players a switch to `formation` removes (D-83): those beyond its slots.
    static func extraPlayers(in tactic: Tactic, for formation: Formation) -> Int {
        let home = tactic.tokens.filter { $0.kind == .player && $0.side == .home }.count
        return max(0, home - formation.slots.count)
    }

    /// Drops the arrows drawn from `ids` (D-83): those starting where one of them stands on that step and no other
    /// player does (`Placement` names an arrow's owner the same way).
    static func removeArrows(from ids: Set<String>, in tactic: inout Tactic) {
        let players = tactic.tokens.filter { $0.kind == .player }.map(\.id)
        for p in tactic.phases.indices {
            // Where each player stands on the step: its own position, else the last one before (as `Timeline` rests).
            var standing: [String: Point] = [:]
            for s in tactic.phases[p].steps.indices {
                for id in players { if let at = tactic.phases[p].steps[s].positions[id] { standing[id] = at } }
                let gone = Set(ids.compactMap { standing[$0] })
                let owned = gone.subtracting(players.filter { !ids.contains($0) }.compactMap { standing[$0] })
                guard !owned.isEmpty else { continue }
                tactic.phases[p].steps[s].arrows.removeAll { arrow in arrow.points.first.map { owned.contains($0) } ?? false }
            }
        }
    }

    static func unusedID(base: String, in tokens: [Token]) -> String {
        let taken = Set(tokens.map(\.id))
        if !taken.contains(base) { return base }
        return (2...).lazy.map { "\(base)-\($0)" }.first { !taken.contains($0) }!
    }
}
