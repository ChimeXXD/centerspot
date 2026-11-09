import Foundation

/// A whole move: the pitch, the two sides, the tokens and their steps (SPEC §2, docs/FORMAT.md).
/// Read files with `TacticFormat.decode`, which applies every refuse and repair rule; decoding this type
/// directly only checks its shape.
struct Tactic: Codable, Sendable, Hashable, Identifiable {
    /// The `.tactic` format version this build reads and writes.
    static let currentSchemaVersion = 1

    var id: String
    var title: String
    var pitch: Pitch
    /// Exactly two: home, then away.
    var sides: [Side]
    var tokens: [Token]
    var phases: [Phase]
    var app: AppInfo?

    /// Which app wrote the file. Informational only.
    struct AppInfo: Codable, Sendable, Hashable {
        var createdWith: String?
    }

    init(
        id: String,
        title: String,
        pitch: Pitch,
        sides: [Side],
        tokens: [Token],
        phases: [Phase],
        app: AppInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.pitch = pitch
        self.sides = sides
        self.tokens = tokens
        self.phases = phases
        self.app = app
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, pitch, sides, tokens, phases, app
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container, debugDescription: "Unsupported schemaVersion \(version)."
            )
        }
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pitch = try container.decode(Pitch.self, forKey: .pitch)
        sides = try container.decode([Side].self, forKey: .sides)
        tokens = try container.decode([Token].self, forKey: .tokens)
        phases = try container.decode([Phase].self, forKey: .phases)
        // Informational only, so a malformed one is dropped rather than refusing the file.
        app = (try? container.decodeIfPresent(AppInfo.self, forKey: .app)) ?? nil
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(pitch, forKey: .pitch)
        try container.encode(sides, forKey: .sides)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(phases, forKey: .phases)
        try container.encodeIfPresent(app, forKey: .app)
    }
}
