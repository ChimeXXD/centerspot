import SwiftUI

/// Applies `TacticEdits` through the document binding and registers each change with the document's `UndoManager`,
/// so every edit can be undone and redone (SPEC §6) and marks the document as edited for autosave.
@MainActor
struct DocumentEditor {
    let document: Binding<TacticDocument>
    let undoManager: UndoManager?
    /// The saved file's size limit (docs/FORMAT.md); tests pass a small one.
    var byteCap = TacticFormat.maxByteCount
    /// Called when an edit is refused because the file would pass `byteCap`.
    var onTooBig: () -> Void = {}

    var tactic: Tactic { document.wrappedValue.tactic }

    /// Runs `edit` on a copy of the tactic and commits it as one undoable action named `actionName` ("Move player").
    /// An edit that would grow the saved file past the cap doesn't happen (D-69: a file that saved but couldn't reopen
    /// would vanish from the library); it returns false and calls `onTooBig`. Edits that make it smaller always apply.
    @discardableResult
    func apply(_ actionName: String, _ edit: (inout Tactic) -> Void) -> Bool {
        let old = document.wrappedValue.tactic
        var tactic = old
        edit(&tactic)
        if tactic != old, let size = try? TacticFormat.encodedSize(tactic), size > byteCap,
           size > (try? TacticFormat.encodedSize(old)) ?? 0 {
            onTooBig()
            return false
        }
        set(tactic, actionName: actionName)
        return true
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
