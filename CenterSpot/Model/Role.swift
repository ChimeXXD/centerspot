import Foundation

/// A generic football role in our own words, from `presets/roles.json` (D-13, D-14).
struct Role: Codable, Sendable, Hashable, Identifiable {
    enum Line: String, Codable, Sendable, CaseIterable {
        case gk, def, mid, att
    }

    let id: String
    /// Two or three letters for tight spaces ("FB").
    let short: String
    let name: String
    let line: Line
}

extension Role {
    /// The position a role plays as a coach writes it (D-98): "CDM", "LB", "RW". Roles name how a player plays, not
    /// which side; the side comes from where the player stands, `x` on the pitch, mirrored for their side, which
    /// attacks downward.
    static func position(_ roleID: String?, x: Double, side: Side.ID?) -> String? {
        guard let roleID, let code = positions[roleID] else { return nil }
        guard code.sided else { return code.base }
        let left = side == .away ? x > 0.5 : x < 0.5
        return (left ? "L" : "R") + code.base
    }

    /// Each role's position, and whether it takes L or R.
    private static let positions: [String: (base: String, sided: Bool)] = [
        "goalkeeper": ("GK", false), "sweeper-keeper": ("GK", false),
        "centre-back": ("CB", false), "ball-playing-centre-back": ("CB", false),
        "full-back": ("B", true), "inverted-full-back": ("B", true), "wing-back": ("WB", true),
        "holding-midfielder": ("CDM", false), "deep-playmaker": ("CDM", false),
        "box-to-box": ("CM", false), "central-midfielder": ("CM", false),
        "advanced-playmaker": ("CAM", false), "attacking-midfielder": ("CAM", false), "free-role": ("CAM", false),
        "wide-midfielder": ("M", true), "winger": ("W", true), "inside-forward": ("W", true),
        "shadow-striker": ("CF", false), "false-nine": ("CF", false),
        "striker": ("ST", false), "target-forward": ("ST", false), "pressing-forward": ("ST", false),
    ]
}

extension Token {
    /// What the tag over a tapped player reads (D-98): the name given, else the position at `point`; nil for a player
    /// with neither, and for anything that isn't a player.
    func tag(at point: Point) -> String? {
        guard kind == .player else { return nil }
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        return Role.position(roleID, x: point.x, side: side)
    }
}
