import Foundation

/// One keyframe of a move: where every token stands, the runs to the next step, the arrows shown on
/// this step and an optional note (SPEC §2).
struct Step: Codable, Sendable, Hashable, Identifiable {
    /// How long the move to the next step takes, in seconds (docs/FORMAT.md: clamped on read).
    static let durationRange = 0.3...5.0
    static let defaultDuration = 1.2
    /// Notes are truncated to 140 characters on read (docs/FORMAT.md).
    static let maxNoteLength = 140
    /// A step shows at most 30 arrows (docs/FORMAT.md).
    static let maxArrows = 30

    var id: String
    var duration: Double
    /// Keyed by token id. After import every token has an entry.
    var positions: [String: Point]
    /// Keyed by token id. After import each run starts at this step's position and ends at the next step's.
    var runs: [String: Path]
    var arrows: [Arrow]
    var note: String?

    init(
        id: String,
        duration: Double = Step.defaultDuration,
        positions: [String: Point] = [:],
        runs: [String: Path] = [:],
        arrows: [Arrow] = [],
        note: String? = nil
    ) {
        self.id = id
        self.duration = duration
        self.positions = positions
        self.runs = runs
        self.arrows = arrows
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, duration, positions, runs, arrows, note
    }

    /// A missing duration takes the default; missing positions, runs and arrows are empty.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? Self.defaultDuration
        positions = try container.decodeIfPresent([String: Point].self, forKey: .positions) ?? [:]
        runs = try container.decodeIfPresent([String: Path].self, forKey: .runs) ?? [:]
        arrows = try container.decodeIfPresent([Arrow].self, forKey: .arrows) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
    }

    /// Empty runs and arrows are left out, which keeps files and links short.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(duration, forKey: .duration)
        try container.encode(positions, forKey: .positions)
        if !runs.isEmpty { try container.encode(runs, forKey: .runs) }
        if !arrows.isEmpty { try container.encode(arrows, forKey: .arrows) }
        try container.encodeIfPresent(note, forKey: .note)
    }
}
