import SwiftUI

/// Applies `TacticEdits` through the document binding and registers each change with the document's `UndoManager`,
/// so every edit can be undone and redone (SPEC §6) and marks the document as edited for autosave.
@MainActor
struct DocumentEditor {
    let document: Binding<TacticDocument>
    let undoManager: UndoManager?

    var tactic: Tactic { document.wrappedValue.tactic }

    /// Runs `edit` on a copy of the tactic and commits it as one undoable action named `actionName` ("Move player").
    func apply(_ actionName: String, _ edit: (inout Tactic) -> Void) {
        var tactic = document.wrappedValue.tactic
        edit(&tactic)
        set(tactic, actionName: actionName)
    }

    /// Swaps in `new` and registers the swap back. Undo calls this again, which registers the redo.
    func set(_ new: Tactic, actionName: String) {
        let old = document.wrappedValue.tactic
        guard new != old else { return }
        document.wrappedValue.tactic = new
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: UndoTarget.shared) { _ in
            MainActor.assumeIsolated { set(old, actionName: actionName) }
        }
        undoManager.setActionName(actionName)
    }
}

/// `registerUndo(withTarget:)` needs an object; the edits themselves live in the closures.
@MainActor private final class UndoTarget {
    static let shared = UndoTarget()
}
