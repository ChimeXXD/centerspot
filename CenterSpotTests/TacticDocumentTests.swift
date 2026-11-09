import Foundation
import Testing
@testable import CenterSpot

/// Opening and saving go through TacticFormat, so every file is validated (CLAUDE.md rule 4, D-27).
struct TacticDocumentTests {
    @Test func aNewDocumentIsABlankLimeAndCoralTactic() throws {
        let document = TacticDocument(), tactic = document.tactic
        #expect(tactic.tokens.isEmpty)
        #expect(tactic.sides.map(\.colour) == [.lime, .coral])
        #expect(tactic.phases.map(\.steps.count) == [1])
        #expect(try TacticFormat.decode(document.encoded()) == tactic)
    }

    @Test func theBlankTacticMatchesItsWrittenForm() throws {
        let id = UUID()
        #expect(try TacticFormat.decode(TacticDocument.emptyTactic(id: id)) == TacticDocument.blank(id: id))
    }

    @Test func openingAFileValidatesIt() throws {
        let document = try TacticDocument(data: Fixtures.data("overlap-left"))
        #expect(document.tactic == (try Fixtures.tactic("overlap-left")))
    }

    @Test func savingWritesWhatOpensAgain() throws {
        var document = try TacticDocument(data: Fixtures.data("overlap-left"))
        document.tactic.title = "Overlap, take two"
        let reopened = try TacticDocument(data: document.encoded())
        #expect(reopened.tactic == document.tactic)
    }

    @Test(arguments: [
        ("too big", Data(repeating: 0x20, count: TacticFormat.maxByteCount + 1), "This file isn't a tactic we can open."),
        ("not json", Data("hello".utf8), "This file isn't a tactic we can open."),
        ("newer", Data(#"{"schemaVersion": 2}"#.utf8), "Made with a newer version of CenterSpot."),
    ])
    func badFilesGiveThePlainMessage(name: String, data: Data, message: String) {
        let error = #expect(throws: TacticFormatError.self, "\(name)") { try TacticDocument(data: data) }
        #expect(error?.localizedDescription == message, "\(name)")
    }
}

