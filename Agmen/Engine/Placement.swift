import Foundation

/// Football words for where a token stands, for VoiceOver (SPEC §8). Seen from the home side, attacking upward (D-05).
enum Placement {
    /// Named areas first (boxes, edge of the box, centre circle), otherwise the channel and the third.
    static func zone(of point: Point, on kind: Pitch.Kind) -> String {
        // Markings keep full-pitch proportions on every pitch kind, as the renderer draws them (SPEC §4),
        // so zones are measured in full-pitch metres whatever `kind` is.
        let x = point.x * 68, y = point.y * 105
        let fromCentre = abs(x - 34)
        let inSixYardWidth = fromCentre <= 9.16, inBoxWidth = fromCentre <= 20.16, nearBoxWidth = fromCentre <= 24
        if inSixYardWidth && y >= 105 - 5.5 { return "six-yard box" }
        if inBoxWidth && y >= 105 - 16.5 { return "penalty area" }
        if nearBoxWidth && y >= 105 - 16.5 - 6 { return "edge of the box" }
        if inSixYardWidth && y <= 5.5 { return "own six-yard box" }
        if inBoxWidth && y <= 16.5 { return "own penalty area" }
        if nearBoxWidth && y <= 16.5 + 6 { return "edge of own box" }
        if hypot(x - 34, y - 52.5) <= 9.15 { return "centre circle" }

        let channel = channel(of: point.x)
        let third = switch point.y {
        case ..<(1.0 / 3): "defensive third"
        case ..<(2.0 / 3): "middle third"
        default: "final third"
        }
        return "\(channel), \(third)"
    }

    /// The channel across the pitch: "left wing", "left half-space", "centre", "right half-space" or "right wing".
    static func channel(of x: Double) -> String {
        switch x {
        case ..<0.2: "left wing"
        case ..<0.37: "left half-space"
        case ...0.63: "centre"
        case ...0.8: "right half-space"
        default: "right wing"
        }
    }

    /// "Number 9, striker, edge of the box, step 3 of 6". Away players start "Their number…" so sides are never
    /// told apart by colour alone (D-15).
    static func label(for token: Token, in tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0,
                      roles: [Role], includeStep: Bool = true) -> String {
        var parts: [String] = []
        switch token.kind {
        case .ball: parts.append("Ball")
        case .cone: parts.append("Cone")
        case .marker: parts.append("Marker")
        case .player:
            let theirs = token.side == .away
            if let number = token.number {
                parts.append("\(theirs ? "Their number" : "Number") \(number)")
            } else {
                if let name = token.name {
                    parts.append(name)
                    if theirs { parts.append("their player") }
                } else {
                    parts.append(theirs ? "Their player" : "Player")
                }
            }
            if let role = roles.first(where: { $0.id == token.roleID }) { parts.append(role.name.lowercased()) }
        }
        let steps = tactic.phases.indices.contains(phaseIndex) ? tactic.phases[phaseIndex].steps : []
        if steps.indices.contains(stepIndex), let point = Self.position(of: token.id, in: steps, upTo: stepIndex) {
            parts.append(zone(of: point, on: tactic.pitch.kind))
        }
        if includeStep, steps.indices.contains(stepIndex) { parts.append("step \(stepIndex + 1) of \(steps.count)") }
        return parts.joined(separator: ", ")
    }

    /// A token missing from a step keeps its last position (docs/FORMAT.md).
    private static func position(of id: String, in steps: [Step], upTo index: Int) -> Point? {
        steps[...index].reversed().lazy.compactMap { $0.positions[id] }.first
    }
}
