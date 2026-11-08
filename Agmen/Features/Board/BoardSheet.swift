import Foundation

/// The sheets the board can show.
enum BoardSheet: Identifiable, Hashable {
    case player(String)
    case formation
    case note(Int)
    case export

    var id: String {
        switch self {
        case .player(let id): "player-\(id)"
        case .formation: "formation"
        case .note(let index): "note-\(index)"
        case .export: "export"
        }
    }

    var isPlayer: Bool { if case .player = self { true } else { false } }
}

/// What the board is doing: editing a step, playing the move (D4-1) or drawing on it (D4-2).
enum BoardMode: Equatable {
    case editing, playing, drawing
}
