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
        return try validated(tactic, knownRoleIDs: knownRoleIDs)
    }

    private struct VersionProbe: Decodable {
        let schemaVersion: Int
    }

    /// Pretty, key-sorted JSON so files diff cleanly and read well in any editor.
    static func encode(_ tactic: Tactic) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(tactic)
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
