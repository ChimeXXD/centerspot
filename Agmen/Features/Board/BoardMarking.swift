import Foundation

/// What the board does with touches while a mark tool is picked in Draw (D-65): a tap reports where it landed and the
/// token under it; a drag reports where it started and where the finger is, and whether it moves or resizes the selected
/// zone or makes a new one. The board screen turns these into `MarkEdits`.
struct BoardMarking {
    enum DragKind: Equatable {
        case new
        case move(String)
        case resize(String, MarkEdits.Corner)
    }

    struct Drag: Equatable {
        var kind: DragKind
        var start: Point
        var current: Point
    }

    var onTap: (Point, String?) -> Void
    /// A drag's progress; `ended` once the finger lifts.
    var onDrag: (_ drag: Drag, _ ended: Bool) -> Void
    var onCancelDrag: () -> Void
}

/// Draw mode's VoiceOver actions on the marks (D-65): select one (the row then offers Remove), remove it, move a zone,
/// and grow or shrink it from a corner.
struct MarkActions {
    var select: (String) -> Void
    var remove: (String) -> Void
    var moveZone: (String, Nudge) -> Void
    var resizeZone: (String, MarkEdits.Corner, _ grow: Bool) -> Void
}
