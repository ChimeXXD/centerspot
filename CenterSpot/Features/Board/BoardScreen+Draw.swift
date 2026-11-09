import SwiftUI
import UIKit

/// Drawing on the board (D4-2, D-59): each finished stroke becomes one undoable `StrokeEdits` edit. On iPhone the
/// toolbar's Draw switches the finger to drawing; on iPad Draw switches the Pencil to drawing and the finger keeps
/// moving tokens (SPEC §6, D-90). Outside draw mode the Pencil is a finger: it taps and drags players.
extension BoardScreen {
    /// iPad: the Pencil draws, so the finger keeps moving tokens even in draw mode.
    static var pencilDraws: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var strokeInput: StrokeInput { StrokeInput.board(mode, pencilDraws: Self.pencilDraws) }

    /// Opens draw mode, with `kind` picked ("Draw run" picks Run) or the last tool used.
    func startDrawing(_ kind: Arrow.Kind? = nil) {
        if let kind { drawTool = DrawTool(kind) }
        drawEdits = 0
        arrowEdit.strokesAtStart = strokeCount
        dragPreview = nil
        clearMarkState()
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            showsStepActions = false
            mode = .drawing
        }
    }

    /// Done keeps the strokes and marks, finishing a line being tapped out; each one stays in the undo history.
    func finishDrawing() {
        if strokeCount > arrowEdit.strokesAtStart { Onboarding.shared.done(DrawTip()) }
        finishLine()
        clearMarkState()
        drawEdits = 0
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { mode = .editing }
    }

    /// Every arrow and run on the move, all steps.
    var strokeCount: Int { steps.reduce(0) { $0 + $1.arrows.count + $1.runs.count } }

    /// Cancel leaves without changes: it drops a line being tapped out and undoes every edit made since draw mode opened.
    func cancelDrawing() {
        clearMarkState()
        for _ in 0..<drawEdits where undoManager?.canUndo == true { undoManager?.undo() }
        drawEdits = 0
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { mode = .editing }
    }

    /// A finished stroke from `BoardCanvas`: what it does depends on the picked kind and where it started (D-59), and it
    /// takes the Shape picked on the panel (D-72).
    func drawStroke(_ points: [Point], from tokenID: String?) {
        guard let kind = drawTool.arrowKind else { return }
        var outcome = StrokeEdits.Outcome()
        let shape = arrowEdit.shape
        let applied = applyEdit("Draw \(DrawTool(kind).title.lowercased())") {
            outcome = StrokeEdits.draw(points, kind: kind, shape: shape, from: tokenID, step: current, in: &$0)
        }
        guard applied else { return }
        strokeDrew(outcome, shape: shape)
        if outcome.hitStepLimit {
            show("A move can have up to \(Phase.stepCountRange.upperBound) steps, so nothing can run from the last one.")
        } else if outcome.hitArrowLimit {
            show("A step shows up to \(Step.maxArrows) lines.")
        }
    }

    /// One undoable edit. In draw mode it is counted when it changed the tactic (an unchanged edit registers no undo),
    /// so Cancel undoes exactly the edits made there and nothing from before.
    @discardableResult
    func applyEdit(_ actionName: String, _ edit: (inout Tactic) -> Void) -> Bool {
        let before = tactic
        guard editor.apply(actionName, edit) else { return false }
        if mode == .drawing, tactic != before { drawEdits += 1 }
        return true
    }

    /// The inspector opens only while editing: in iPad draw mode its edits would land between the strokes Cancel undoes.
    func doubleTapBoard(_ id: String) {
        if mode == .editing { openPlayer(id) }
    }
}
