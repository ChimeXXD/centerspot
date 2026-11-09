import Foundation

/// What a step marks on the grass (D-65): zones, shape lines and glows. Optional in format v1 (older files have none);
/// like arrows they belong to their step and fade in and out with it, and a mark with the same id on the next step eases
/// into it instead (docs/FORMAT.md).
struct Marks: Codable, Sendable, Hashable {
    /// Zones, lines and glows together, per step (docs/FORMAT.md: more refuses the file).
    static let maxCount = 12

    var zones: [Zone]
    var lines: [ShapeLine]
    var glows: [Glow]

    init(zones: [Zone] = [], lines: [ShapeLine] = [], glows: [Glow] = []) {
        self.zones = zones
        self.lines = lines
        self.glows = glows
    }

    var count: Int { zones.count + lines.count + glows.count }
    var isEmpty: Bool { count == 0 }
    /// Every mark's id: zones, then lines, then glows.
    var ids: [String] { zones.map(\.id) + lines.map(\.id) + glows.map(\.id) }

    private enum CodingKeys: String, CodingKey {
        case zones, lines, glows
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zones = try container.decodeIfPresent([Zone].self, forKey: .zones) ?? []
        lines = try container.decodeIfPresent([ShapeLine].self, forKey: .lines) ?? []
        glows = try container.decodeIfPresent([Glow].self, forKey: .glows) ?? []
    }

    /// Empty lists are left out, which keeps files and links short.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !zones.isEmpty { try container.encode(zones, forKey: .zones) }
        if !lines.isEmpty { try container.encode(lines, forKey: .lines) }
        if !glows.isEmpty { try container.encode(glows, forKey: .glows) }
    }
}
