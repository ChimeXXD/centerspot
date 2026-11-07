import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The `.tactic` document type, exported in project.yml (D-09, docs/FORMAT.md).
    static let tactic = UTType(exportedAs: "dev.chime.agmen.tactic")
}

/// A `.tactic` file: the value the board edits (the library stores it, D-56) and, later, file export. Opening runs every rule in docs/FORMAT.md through `TacticFormat`, so a bad file shows a plain
/// error and never crashes (CLAUDE.md rule 4); saving writes clean v1 JSON.
struct TacticDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.tactic]

    var tactic: Tactic

    init() {
        tactic = Self.blank()
    }

    init(tactic: Tactic) {
        self.tactic = tactic
    }

    init(data: Data) throws(TacticFormatError) {
        tactic = try TacticFormat.decode(data)
    }

    init(configuration: ReadConfiguration) throws {
        // Refuse an oversized file before reading it into memory, when the system tells us its size.
        if let size = configuration.file.fileAttributes[FileAttributeKey.size.rawValue] as? Int, size > TacticFormat.maxByteCount {
            throw TacticFormatError.unreadable
        }
        guard let data = configuration.file.regularFileContents else { throw TacticFormatError.unreadable }
        try self.init(data: data)
    }

    func encoded() throws -> Data {
        try TacticFormat.encode(tactic)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try encoded())
    }

    /// A blank full-pitch tactic: lime and coral sides (D-53), no tokens, one phase with one step (valid under D-27).
    static func blank(id: UUID = UUID()) -> Tactic {
        Tactic(
            id: id.uuidString,
            title: "Untitled tactic",
            pitch: Pitch(kind: .full, style: .stripes),
            sides: [Side(id: .home, name: "Us", colour: .lime), Side(id: .away, name: "Them", colour: .coral)],
            tokens: [],
            phases: [Phase(id: .main, name: "Main", steps: [Step(id: "s1")])],
            app: Tactic.AppInfo(createdWith: "Agmen 0.1.0")
        )
    }
}
