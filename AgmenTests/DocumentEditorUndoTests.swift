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
        ("Draw run", { StrokeEdits.draw([Point(x: 0.15, y: 0.25), Point(x: 0.1, y: 0.5)], kind: .run, from: "h3", step: 1, in: &$0) }),
        ("Draw pass", { StrokeEdits.draw([Point(x: 0.3, y: 0.4), Point(x: 0.6, y: 0.5)], kind: .pass, from: "h8", step: 4, in: &$0) }),
        ("Draw zone", { _ = MarkEdits.addZone(from: Point(x: 0.6, y: 0.2), to: Point(x: 0.9, y: 0.5), step: 0, in: &$0) }),
        ("Move zone", { MarkEdits.moveZone("z1", by: 0.1, 0, step: stepWith("z1", in: $0), in: &$0) }),
        ("Resize zone", { MarkEdits.resizeZone("z1", corner: .topRight, to: Point(x: 0.5, y: 0.95), step: stepWith("z1", in: $0), in: &$0) }),
        ("Draw line", { _ = MarkEdits.addLine(["h5", "h4", "h2"], step: 1, in: &$0) }),
        ("Add glow", { _ = MarkEdits.addRings(on: "h9", step: 2, in: &$0) }),
        ("Add heat", { _ = MarkEdits.addHeat(at: Point(x: 0.5, y: 0.8), step: 2, in: &$0) }),
        ("Remove line", { MarkEdits.remove("l1", step: stepWith("l1", in: $0), in: &$0) }),
        // D-72: dragging the middle dot is one edit on lift, and so is removing an arrow.
        ("Bend arrow", { StrokeEdits.bend(arrow: 0, to: bentDot(of: $0), step: stepWithArrow($0), in: &$0) }),
        ("Remove arrow", { StrokeEdits.removeArrow(at: 0, step: stepWithArrow($0), in: &$0) }),
    ]

    /// The first step with an arrow (-1 if none).
    nonisolated private static func stepWithArrow(_ tactic: Tactic) -> Int {
        tactic.phases.first?.steps.firstIndex { !$0.arrows.isEmpty } ?? -1
    }

    /// A dot 0.08 to the side of the middle of that step's first arrow, so dragging it there bends it.
    nonisolated private static func bentDot(of tactic: Tactic) -> Point {
        guard let arrow = tactic.phases.first?.steps[safe: stepWithArrow(tactic)]?.arrows.first,
              let a = arrow.points.first, let b = arrow.points.last else { return .centre }
        let dx = b.x - a.x, dy = b.y - a.y, length = max(hypot(dx, dy), 1e-9)
        return Point(x: (a.x + b.x) / 2 - dy / length * 0.08, y: (a.y + b.y) / 2 + dx / length * 0.08)
    }

    /// The step holding the hero's mark `id` wherever the edits before have moved it (-1 if none).
    nonisolated private static func stepWith(_ id: String, in tactic: Tactic) -> Int {
        tactic.phases.first?.steps.firstIndex { $0.marks.ids.contains(id) } ?? -1
    }

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

    /// D-69: an edit that would grow the saved file past the cap doesn't happen (nothing can save and then fail to
    /// reopen); it says so, and registers no undo. An edit that makes it smaller still goes through.
    @Test func anEditThatWouldOverflowTheFileIsRefused() throws {
        let box = Box(try Fixtures.tactic("overlap-left"))
        let undo = UndoManager()
        undo.groupsByEvent = false
        let size = try TacticFormat.encodedSize(box.document.tactic)
        var refusals = 0
        let editor = DocumentEditor(document: Binding(get: { box.document }, set: { box.document = $0 }),
                                    undoManager: undo, byteCap: size + 10, onTooBig: { refusals += 1 })
        let before = box.document.tactic

        undo.beginUndoGrouping()
        let grew = editor.apply("Add step") { _ = TacticEdits.addStep(after: 0, in: &$0) }
        undo.endUndoGrouping()
        #expect(!grew)
        #expect(box.document.tactic == before, "the step was not added")
        #expect(refusals == 1)
        #expect(undo.undoActionName.isEmpty, "nothing to undo")

        undo.beginUndoGrouping()
        let shrank = editor.apply("Delete step") { _ = TacticEdits.deleteStep(at: 4, in: &$0) }
        undo.endUndoGrouping()
        #expect(shrank)
        #expect(box.document.tactic.phases[0].steps.count == 4)
        #expect(refusals == 1)
    }

    /// D-69 holds for the draw tools too: a mark that would pass the cap isn't added; removing one always works.
    @Test func aMarkThatWouldOverflowTheFileIsRefused() throws {
        let box = Box(try Fixtures.tactic("overlap-left"))
        let undo = UndoManager()
        undo.groupsByEvent = false
        let size = try TacticFormat.encodedSize(box.document.tactic)
        var refusals = 0
        let editor = DocumentEditor(document: Binding(get: { box.document }, set: { box.document = $0 }),
                                    undoManager: undo, byteCap: size + 10, onTooBig: { refusals += 1 })
        let before = box.document.tactic
        for (name, edit) in Self.markAdds {
            undo.beginUndoGrouping()
            #expect(!editor.apply(name, edit), "\(name)")
            undo.endUndoGrouping()
        }
        #expect(box.document.tactic == before)
        #expect(refusals == Self.markAdds.count)
        #expect(undo.undoActionName.isEmpty)

        undo.beginUndoGrouping()
        #expect(editor.apply("Remove zone") { MarkEdits.remove("z1", step: 3, in: &$0) })
        undo.endUndoGrouping()
        #expect(try TestTactics.marks(3, of: box.document.tactic).zones.isEmpty)
    }

    nonisolated private static let markAdds: [(name: String, edit: @Sendable (inout Tactic) -> Void)] = [
        ("Draw zone", { _ = MarkEdits.addZone(from: Point(x: 0.6, y: 0.2), to: Point(x: 0.9, y: 0.5), step: 0, in: &$0) }),
        ("Draw line", { _ = MarkEdits.addLine(["h5", "h4", "h2"], step: 1, in: &$0) }),
        ("Add glow", { _ = MarkEdits.addRings(on: "h9", step: 2, in: &$0) }),
        ("Add heat", { _ = MarkEdits.addHeat(at: Point(x: 0.5, y: 0.8), step: 2, in: &$0) }),
    ]
}
