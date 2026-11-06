import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The `.tactic` document type, exported in project.yml (D-09, docs/FORMAT.md).
    static let tactic = UTType(exportedAs: "dev.chime.agmen.tactic")
}

/// Day 0 placeholder: keeps the file's bytes as they are. Day 2 replaces `data` with the validated `Tactic` model.
struct TacticDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.tactic]

    /// Files over 256 KB are refused (CLAUDE.md rule 4, docs/FORMAT.md).
    static let maxFileSize = TacticFormat.maxByteCount

    var data: Data

    init(data: Data = TacticDocument.emptyTactic()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard data.count <= Self.maxFileSize else {
            throw CocoaError(.fileReadTooLarge)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    /// A blank full-pitch tactic: two sides, no tokens, one phase with one step (valid under D-27).
    static func emptyTactic(id: UUID = UUID()) -> Data {
        Data("""
        {
          "schemaVersion": 1,
          "id": "\(id.uuidString)",
          "title": "Untitled tactic",
          "pitch": { "kind": "full", "style": "stripes" },
          "sides": [
            { "id": "home", "name": "Us", "colour": "blue" },
            { "id": "away", "name": "Them", "colour": "orange" }
          ],
          "tokens": [],
          "phases": [
            { "id": "main", "name": "Main", "steps": [ { "id": "s1", "duration": 1.2, "positions": {} } ] }
          ],
          "app": { "createdWith": "Agmen 0.1.0" }
        }
        """.utf8)
    }
}
