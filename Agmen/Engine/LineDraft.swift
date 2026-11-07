import Foundation

/// A shape line being tapped out in Draw › Line (D-65, mockup `draw.line`): tap players in order to join them; tapping
/// the last one again finishes. A player already in the line is ignored, and so is anyone but a player; a player of the
/// other side starts nothing ("One side per line"). The board keeps it outside the document until it is finished, so a
/// whole line is one undoable edit (`MarkEdits.addLine`).
struct LineDraft: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        /// The first player of a new line.
        case started
        case added
        /// The last player was tapped again, or the line is a whole team: commit it.
        case finished
        /// The grass, a ball or cone, or a player already in the line.
        case ignored
        case otherSide
    }

    private(set) var tokens: [String] = []

    var isEmpty: Bool { tokens.isEmpty }
    /// Two players at least, so it can be drawn and kept.
    var isComplete: Bool { tokens.count >= ShapeLine.minTokens }

    mutating func tap(_ id: String?, in tactic: Tactic) -> Outcome {
        guard let id, let token = tactic.tokens.first(where: { $0.id == id }), token.kind == .player else { return .ignored }
        guard let first = tokens.first else {
            tokens = [id]
            return .started
        }
        if id == tokens.last { return .finished }
        if tokens.contains(id) { return .ignored }
        guard token.side == tactic.tokens.first(where: { $0.id == first })?.side else { return .otherSide }
        tokens.append(id)
        return tokens.count == ShapeLine.maxTokens ? .finished : .added
    }

    mutating func clear() {
        tokens = []
    }
}
