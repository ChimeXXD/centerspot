import SwiftUI
import UIKit

/// Drawing on the board (D4-2, D-59): each finished stroke becomes one undoable `StrokeEdits` edit. On iPhone the
/// toolbar's Draw switches the finger to drawing; on iPad the Pencil always draws and the finger always moves tokens
/// (SPEC §6).
extension BoardScreen {
    /// iPad: the Pencil draws, so the finger keeps moving tokens even in draw mode.
    static var pencilDraws: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var strokeInput: StrokeInput {
        switch mode {
        case .editing: .pencil
        case .playing: .none
        case .drawing: Self.pencilDraws ? .pencil : .fingerAndPencil
        }
    }

    /// Opens draw mode, with `kind` picked ("Draw run" picks Run) or the last kind used.
    func startDrawing(_ kind: Arrow.Kind? = nil) {
        if let kind { drawKind = kind }
        drawEdits = 0
        dragPreview = nil
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            showsStepActions = false
            mode = .drawing
        }
    }

    /// Done keeps the strokes; each one stays in the undo history.
    func finishDrawing() {
        drawEdits = 0
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { mode = .editing }
    }

    /// Cancel leaves without changes: it undoes every edit made since draw mode opened.
    func cancelDrawing() {
        for _ in 0..<drawEdits where undoManager?.canUndo == true { undoManager?.undo() }
        drawEdits = 0
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { mode = .editing }
    }

    /// A finished stroke from `BoardCanvas`: what it does depends on the picked kind and where it started (D-59).
    func drawStroke(_ points: [Point], from tokenID: String?) {
        let kind = drawKind
        var outcome = StrokeEdits.Outcome()
        applyEdit("Draw \(DrawPanel.noun(kind))") {
            outcome = StrokeEdits.draw(points, kind: kind, from: tokenID, step: current, in: &$0)
        }
        if outcome.hitStepLimit {
            show("A move can have up to \(Phase.stepCountRange.upperBound) steps, so nothing can run from the last one.")
        } else if outcome.hitArrowLimit {
            show("A step shows up to \(Step.maxArrows) lines.")
        }
    }

    /// One undoable edit. In draw mode it is counted when it changed the tactic (an unchanged edit registers no undo),
    /// so Cancel undoes exactly the edits made there and nothing from before.
    func applyEdit(_ actionName: String, _ edit: (inout Tactic) -> Void) {
        let before = tactic
        editor.apply(actionName, edit)
        if mode == .drawing, tactic != before { drawEdits += 1 }
    }

    /// The inspector opens only while editing: in iPad draw mode its edits would land between the strokes Cancel undoes.
    func doubleTapBoard(_ id: String) {
        if mode == .editing { openPlayer(id) }
    }
}
