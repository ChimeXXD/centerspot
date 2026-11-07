import Foundation

/// Reads and writes `.tactic` JSON (docs/FORMAT.md). The single way in for files and, later, links.
enum TacticFormat {
    /// Files and decoded link payloads over 256 KB are refused before decoding (CLAUDE.md rule 4).
    static let maxByteCount = 256 * 1024
    /// A board holds 0…30 tokens; an empty board is valid (D-27).
    static let maxTokens = 30

    /// Decodes and validates a tactic: structure and safety problems throw, cosmetic values are repaired.
    /// - Parameter knownRoleIDs: role ids to keep; `nil` keeps every role id.
    static func decode(
        _ data: Data,
        knownRoleIDs: Set<String>? = bundledRoleIDs
    ) throws(TacticFormatError) -> Tactic {
        guard data.count <= maxByteCount else { throw .unreadable }

        // Read the version on its own first, so a newer file whose shape v1 can't parse still gets the
        // newer-version message rather than the generic one.
        guard let version = try? JSONDecoder().decode(VersionProbe.self, from: data).schemaVersion else {
            throw .unreadable
        }
        guard version <= Tactic.currentSchemaVersion else { throw .newerVersion }
        guard version == Tactic.currentSchemaVersion else { throw .unreadable }

        guard let tactic = try? JSONDecoder().decode(Tactic.self, from: data) else { throw .unreadable }
        let repaired = try validated(tactic, knownRoleIDs: knownRoleIDs)

        // The cap holds for the tactic as Agmen will save it too. Repairs can grow a file (every step gets a position
        // for every token), and a saved file over the cap could never be opened again (D6-3 fuzz).
        // `encode` writes compact JSON when the pretty form is over the cap, so the compact size is the one to check.
        guard let saved = try? encodedSize(repaired), saved <= maxByteCount else { throw .unreadable }
        return repaired
    }

    /// The tactic's smallest saved size (compact JSON): the size the cap is checked against, on import and on every
    /// in-app edit (D-69).
    static func encodedSize(_ tactic: Tactic) throws -> Int {
        try encoder(pretty: false).encode(tactic).count
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }

    /// Pretty, key-sorted JSON so files diff cleanly and read well in any editor. A tactic whose pretty form would pass
    /// the size cap is written compactly instead, so an imported tactic always saves under the cap; in-app edits that
    /// would pass it are refused by `DocumentEditor` (D-69).
    static func encode(_ tactic: Tactic) throws -> Data {
        let pretty = try encoder(pretty: true).encode(tactic)
        guard pretty.count > maxByteCount else { return pretty }
        return try encoder(pretty: false).encode(tactic)
    }

    private static func encoder(pretty: Bool) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            : [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// Role ids from the bundled `roles.json` (D-14), or `nil` if it can't be read.
    static let bundledRoleIDs: Set<String>? = {
        guard let url = Bundle.main.url(forResource: "roles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(RoleFile.self, from: data)
        else { return nil }
        return Set(file.roles.map(\.id))
    }()

    private struct RoleFile: Decodable {
        struct Entry: Decodable { let id: String }
        let roles: [Entry]
    }
}
