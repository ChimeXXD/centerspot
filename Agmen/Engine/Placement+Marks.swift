import Foundation

/// Football words for marks (D-65, SPEC §8): VoiceOver labels and the draw row's "Zone 1 · step 4". A mark is numbered
/// among its kind on its step, in drawing order.
extension Placement {
    /// "Zone 1, left wing, step 4", "Line joining 2, 5 and 4, step 4", "Glow on number 3, step 4", "Heat glow, penalty
    /// area, step 4". Their players read "their" first, so sides are never told apart by colour alone (D-15).
    static func label(forMark id: String, in tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> String? {
        guard let marks = marks(in: tactic, stepIndex: stepIndex, phaseIndex: phaseIndex) else { return nil }
        let step = "step \(stepIndex + 1)"
        if let i = marks.zones.firstIndex(where: { $0.id == id }) {
            return "Zone \(i + 1), \(channel(of: marks.zones[i].centre.x)), \(step)"
        }
        if let line = marks.lines.first(where: { $0.id == id }) {
            let players = line.tokens.compactMap { id in tactic.tokens.first { $0.id == id } }
            let theirs = players.first?.side == .away ? "their " : ""
            return "Line joining \(theirs)\(list(players.map(shortName))), \(step)"
        }
        guard let glow = marks.glows.first(where: { $0.id == id }) else { return nil }
        switch glow.target {
        case .token(let tokenID):
            guard let token = tactic.tokens.first(where: { $0.id == tokenID }) else { return "Glow, \(step)" }
            let theirs = token.side == .away ? "their " : ""
            let who = token.number.map { "\(theirs)number \($0)" } ?? token.name.map { "\(theirs)\($0)" } ?? "\(theirs)player"
            return "Glow on \(who), \(step)"
        case .spot(let centre, _):
            return "Heat glow, \(zone(of: centre, on: tactic.pitch.kind)), \(step)"
        }
    }

    /// The draw row's label for the selected mark: "Zone 1 · step 4", "Line 2 · step 4", "Glow 1 · step 4".
    static func rowLabel(forMark id: String, in tactic: Tactic, stepIndex: Int, phaseIndex: Int = 0) -> String? {
        guard let marks = marks(in: tactic, stepIndex: stepIndex, phaseIndex: phaseIndex) else { return nil }
        let kind: String, index: Int
        if let i = marks.zones.firstIndex(where: { $0.id == id }) {
            (kind, index) = ("Zone", i)
        } else if let i = marks.lines.firstIndex(where: { $0.id == id }) {
            (kind, index) = ("Line", i)
        } else if let i = marks.glows.firstIndex(where: { $0.id == id }) {
            (kind, index) = ("Glow", i)
        } else {
            return nil
        }
        return "\(kind) \(index + 1) · step \(stepIndex + 1)"
    }

    private static func marks(in tactic: Tactic, stepIndex: Int, phaseIndex: Int) -> Marks? {
        guard tactic.phases.indices.contains(phaseIndex), tactic.phases[phaseIndex].steps.indices.contains(stepIndex) else {
            return nil
        }
        return tactic.phases[phaseIndex].steps[stepIndex].marks
    }

    /// A player in a list: their number, else their name, else "player".
    private static func shortName(_ token: Token) -> String {
        token.number.map(String.init) ?? token.name ?? "player"
    }

    /// "2", "2 and 5", "2, 5 and 4".
    private static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
