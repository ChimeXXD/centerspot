import Foundation
import SwiftUI
import Testing
@testable import Agmen

/// SPEC §6 / D3-2: every board edit goes through `DocumentEditor`, and each one can be undone and redone through the
/// document's `UndoManager`.
@MainActor
struct DocumentEditorUndoTests {
    /// Holds the document the way DocumentGroup's binding would.
    final class Box {
        var document: TacticDocument
        init(_ tactic: Tactic) { document = TacticDocument(); document.tactic = tactic }
    }

    /// A box, an editor over it, and an undo manager that groups each edit by hand (no run loop in tests).
    private func make() throws -> (Box, DocumentEditor, UndoManager) {
        let box = Box(try Fixtures.tactic("overlap-left"))
        let undo = UndoManager()
        undo.groupsByEvent = false
        let editor = DocumentEditor(document: Binding(get: { box.document }, set: { box.document = $0 }), undoManager: undo)
        return (box, editor, undo)
    }

    nonisolated private static let edits: [(name: String, edit: @Sendable (inout Tactic) -> Void)] = [
        ("Add step", { _ = TacticEdits.addStep(after: 1, in: &$0) }),
        ("Delete step", { _ = TacticEdits.deleteStep(at: 2, in: &$0) }),
        ("Move step", { TacticEdits.moveStep(from: 0, to: 3, in: &$0) }),
        ("Change duration", { TacticEdits.setDuration(2.5, step: 1, in: &$0) }),
        ("Move player", { TacticEdits.moveToken("h9", to: Point(x: 0.3, y: 0.7), step: 0, in: &$0) }),
        ("Add player", { _ = TacticEdits.addToken(.ourPlayer, in: &$0) }),
        ("Remove player", { TacticEdits.deleteToken("h3", in: &$0) }),
    ]

    @Test(arguments: edits.indices)
    func eachEditUndoesAndRedoes(_ i: Int) throws {
        let (box, editor, undo) = try make()
        let before = box.document.tactic
        undo.beginUndoGrouping()
        editor.apply(Self.edits[i].name, Self.edits[i].edit)
        undo.endUndoGrouping()
        let after = box.document.tactic
        #expect(after != before, "the edit changed the tactic")
        #expect(undo.undoActionName == Self.edits[i].name)

        undo.undo()
        #expect(box.document.tactic == before)
        #expect(undo.canRedo)
        undo.redo()
        #expect(box.document.tactic == after)
    }

    @Test func editsUndoInReverseOrder() throws {
        let (box, editor, undo) = try make()
        var history = [box.document.tactic]
        for (name, edit) in Self.edits {
            undo.beginUndoGrouping()
            editor.apply(name, edit)
            undo.endUndoGrouping()
            history.append(box.document.tactic)
        }
        for expected in history.dropLast().reversed() {
            undo.undo()
            #expect(box.document.tactic == expected)
        }
        #expect(!undo.canUndo)
    }

    @Test func anEditThatChangesNothingRegistersNoUndo() throws {
        let (_, editor, undo) = try make()
        undo.beginUndoGrouping()
        editor.apply("Change duration") { _ in }
        undo.endUndoGrouping()
        // An empty group still reports canUndo; a registered edit would have named it.
        #expect(undo.undoActionName.isEmpty)
    }
}
