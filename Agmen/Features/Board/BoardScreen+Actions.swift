import SwiftUI

/// What the board's gestures and buttons do. Each edit is one undoable action named for the Edit menu.
extension BoardScreen {
    func tap(_ id: String?) {
        withAnimation(Tokens.Motion.ease(Tokens.Motion.select)) {
            selection = id
            showsStepActions = false
        }
    }

    func openPlayer(_ id: String) {
        selection = id
        showsStepActions = false
        guard tactic.tokens.first(where: { $0.id == id })?.kind == .player else { return }
        sheet = .player(id)
    }

    func endDrag(_ id: String, _ point: Point) {
        let name = tactic.tokens.first { $0.id == id }.map(Self.moveActionName) ?? "Move"
        applyEdit(name) { TacticEdits.moveToken(id, to: point, step: current, in: &$0) }
        dragPreview = nil
        selection = id
        showsStepActions = false
    }

    func nudge(_ id: String, _ point: Point) {
        let name = tactic.tokens.first { $0.id == id }.map(Self.moveActionName) ?? "Move"
        applyEdit(name) { TacticEdits.moveToken(id, to: point, step: current, in: &$0) }
    }

    static func moveActionName(_ token: Token) -> String {
        switch token.kind {
        case .player: "Move player"
        case .ball: "Move ball"
        case .cone, .marker: "Move cone"
        }
    }

    // MARK: Steps

    func selectStep(_ index: Int) {
        if index == current {
            // The row under the pitch shows one thing at a time: the step's actions replace the selection.
            withAnimation(Tokens.Motion.ease(Tokens.Motion.select)) {
                showsStepActions.toggle()
                selection = nil
            }
        } else {
            withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
                stepIndex = index
                showsStepActions = false
            }
        }
    }

    func addStep(_ actionName: String) {
        var added: Int?
        editor.apply(actionName) { added = TacticEdits.addStep(after: current, in: &$0) }
        guard let added else {
            show("A move can have up to \(Phase.stepCountRange.upperBound) steps.")
            return
        }
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            stepIndex = added
            showsStepActions = false
        }
        pulse += 1
    }

    func deleteStep() {
        // Read before the edit: `current` re-clamps once the step is gone, which would skip a step back from the last.
        let index = current
        var deleted = false
        editor.apply("Delete step") { deleted = TacticEdits.deleteStep(at: index, in: &$0) }
        guard deleted else { return }
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            stepIndex = max(0, index - 1)
            showsStepActions = false
        }
        show("Deleted step \(index + 1)", offersUndo: true, returnsTo: index)
    }

    /// Keeps the same step on screen when another chip moves past it.
    func moveStep(_ from: Int, _ to: Int) {
        let index = current
        editor.apply("Move step") { TacticEdits.moveStep(from: from, to: to, in: &$0) }
        if from == index { stepIndex = to }
        else if from < index, to >= index { stepIndex = index - 1 }
        else if from > index, to <= index { stepIndex = index + 1 }
    }

    func setDuration(_ seconds: Double) {
        editor.apply("Change duration") { TacticEdits.setDuration(seconds, step: current, in: &$0) }
    }

    func setPitchKind(_ kind: Pitch.Kind) {
        editor.apply("Change pitch") { TacticEdits.setPitch(kind: kind, style: $0.pitch.style, in: &$0) }
    }

    func setPitchStyle(_ style: Pitch.Style) {
        editor.apply("Change pitch") { TacticEdits.setPitch(kind: $0.pitch.kind, style: style, in: &$0) }
    }

    // MARK: Tokens

    func addToken(_ kind: TacticEdits.NewToken) {
        let name = switch kind {
        case .ourPlayer, .theirPlayer: "Add player"
        case .ball: "Add ball"
        case .cone: "Add cone"
        }
        var id: String?
        editor.apply(name) { id = TacticEdits.addToken(kind, in: &$0) }
        guard let id else {
            show(kind == .ball ? "There's already a ball on the board." : "A board holds up to \(TacticFormat.maxTokens) players, balls and cones.")
            return
        }
        withAnimation(Tokens.Motion.ease(Tokens.Motion.select)) {
            selection = id
            showsStepActions = false
        }
    }

    func removeToken(_ token: Token) {
        editor.apply(token.kind == .player ? "Remove player" : "Remove \(Self.selectionLabel(token).lowercased())") {
            TacticEdits.deleteToken(token.id, in: &$0)
        }
        if sheet?.isPlayer == true { sheet = nil }
        selection = nil
        let what = switch token.kind {
        case .player: token.number.map { "number \($0)" } ?? token.name ?? "player"
        case .ball: "ball"
        case .cone, .marker: "cone"
        }
        show("Removed \(what)", offersUndo: true)
    }

    // MARK: Toasts

    /// With `offersUndo`, the toast remembers the tactic the edit left, so its Undo only undoes that edit.
    func show(_ message: String, offersUndo: Bool = false, returnsTo step: Int? = nil) {
        withAnimation(Tokens.Motion.ease(Tokens.Motion.toast)) {
            toast = BoardToast(message: message, undoesTo: offersUndo ? tactic : nil, returnsTo: step)
        }
    }

    /// The toast's Undo: a later edit has replaced the one it names, so undoing now would undo the wrong thing.
    func undoFromToast(_ toast: BoardToast) {
        if toast.undoesTo == tactic {
            undoManager?.undo()
            if let step = toast.returnsTo {
                withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { stepIndex = step }
            }
        }
        self.toast = nil
    }

    /// Renames the tactic as one undoable edit; the library renames its file on the next save (D-56).
    func rename(to title: String) {
        editor.apply("Rename") { $0.title = TacticLibrary.cleanTitle(title) }
    }
}
