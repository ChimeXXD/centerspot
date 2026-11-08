import Foundation

/// Draw mode's arrow bending (D-72), while an arrow tool is picked: a tap on the pitch reports where it landed (the
/// board screen selects the bent arrow there); the selected arrow's middle dot is drawn at `dot`, and a touch that
/// starts on it drags it instead of drawing. The board screen previews the bend and commits it once on lift.
struct BoardBending {
    /// The selected arrow's middle dot, or nil when none is selected.
    var dot: Point?
    /// "Bend of 3's run. Drag to change the curve."
    var label: String
    var onTap: (Point) -> Void
    /// Where the dot is being dragged to (unclamped); `ended` once the finger lifts.
    var onDrag: (_ dot: Point, _ ended: Bool) -> Void
    var onCancel: () -> Void
    /// VoiceOver's adjustable action: bend more (true) or less.
    var onAdjust: (_ more: Bool) -> Void
}

/// What Draw remembers about arrows while the board is open: the shape the next one takes (Straight by default, kept
/// across draw sessions but never stored in the file), the selected bent arrow, the dot under the finger, and whether
/// the last stroke drew a straight arrow (for the hint).
struct ArrowEditing: Equatable {
    struct Selected: Equatable {
        let step: Int
        let index: Int
    }

    var shape = ArrowShape.straight
    var selected: Selected?
    var preview: Point?
    var drewStraight = false
}
