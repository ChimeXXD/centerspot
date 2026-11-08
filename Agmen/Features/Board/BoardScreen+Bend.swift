import SwiftUI

/// Draw's arrow shapes (D-72, mockup draw--shape-straight / -curved, ipad-draw--landscape): the Shape switch, the
/// selected bent arrow and its middle dot. Dragging the dot previews the bend on a copy and commits it once on lift
/// through `applyEdit`, so it is one undo step, Cancel takes it back (D-62) and the size cap holds (D-69).
extension BoardScreen {
    /// The Draw panel's Shape switch. Picking a shape starts the hint over.
    var shapeBinding: Binding<ArrowShape> {
        Binding(get: { arrowEdit.shape }, set: { shape in
            arrowEdit.shape = shape
            arrowEdit.drewStraight = false
        })
    }

    private var pitchAspect: Double { tactic.pitch.kind.size.length / tactic.pitch.kind.size.width }

    /// The selected arrow on this step, while it is still there with a bend (an undo or a straightening drops it).
    var selectedArrow: Int? {
        guard mode == .drawing, drawTool.arrowKind != nil, let selected = arrowEdit.selected, selected.step == current,
              steps.indices.contains(current), steps[current].arrows.indices.contains(selected.index),
              steps[current].arrows[selected.index].points.count > 2 else { return nil }
        return selected.index
    }

    /// The tactic as the board shows it: with the bend under the finger while the dot is dragged.
    var shownTactic: Tactic {
        guard let index = selectedArrow, let dot = arrowEdit.preview else { return tactic }
        var copy = tactic
        StrokeEdits.bend(arrow: index, to: dot, step: current, in: &copy)
        return copy
    }

    /// Where the dot is drawn: the shown arrow's middle; while dragged onto the straight line, under the finger.
    private var bendDot: Point? {
        guard let index = selectedArrow else { return nil }
        // Only the arrow is re-bent here (as `StrokeEdits.bend` does), not a copy of the whole tactic.
        let stored = steps[current].arrows[index].points
        let points = arrowEdit.preview.map { ShapedPath.nudged(stored, dotTo: $0, aspect: pitchAspect) } ?? stored
        if points.count > 2 { return ShapedPath.middle(of: points, aspect: pitchAspect) }
        return arrowEdit.preview?.clamped
    }

    var boardBending: BoardBending? {
        guard mode == .drawing, drawTool.arrowKind != nil else { return nil }
        let label = selectedArrow.flatMap { Placement.bendLabel(forArrow: $0, in: tactic, stepIndex: current) } ?? ""
        return BoardBending(dot: bendDot, label: label, onTap: tapArrow, onDrag: dragBend,
                            onCancel: { arrowEdit.preview = nil }, onAdjust: adjustBend)
    }

    /// The iPhone's hint for arrows (mockup draw--shape-*): the dot's instruction while an arrow is selected, the
    /// straight line's after one was drawn; otherwise the tool's own ("Start on a player to draw their run.").
    var arrowHint: String? {
        guard let kind = drawTool.arrowKind else { return nil }
        if selectedArrow != nil { return "Drag the middle dot to change the bend." }
        return arrowEdit.drewStraight ? "The \(kind.rawValue) goes straight to where you lift." : nil
    }

    /// The iPad row for the selected arrow: "3's run · drag the dot to bend", with Remove.
    var arrowRowLabel: String? {
        selectedArrow.flatMap { Placement.rowLabel(forArrow: $0, in: tactic, stepIndex: current) }
    }

    /// After a stroke: a curved arrow it drew is selected, so its dot shows (D-72); a straight one clears the selection.
    func strokeDrew(_ outcome: StrokeEdits.Outcome, shape: ArrowShape) {
        guard outcome.changed else { return }
        let arrows = steps.indices.contains(current) ? steps[current].arrows : []
        if !outcome.hitArrowLimit, let last = arrows.indices.last, arrows[last].points.count > 2 {
            arrowEdit.selected = .init(step: current, index: last)
        } else {
            arrowEdit.selected = nil
        }
        arrowEdit.drewStraight = shape == .straight
    }

    func clearArrowState() {
        arrowEdit.selected = nil
        arrowEdit.preview = nil
        arrowEdit.drewStraight = false
    }

    /// A tap selects the bent arrow under it (its dot shows), or clears the selection on bare grass.
    private func tapArrow(_ point: Point) {
        guard steps.indices.contains(current), arrowEdit.preview == nil else { return }
        let reach = boardWidth > 0 ? Double(Tokens.Size.touch / 2 / boardWidth) : 0.04
        let index = ArrowHit.bendable(near: point, in: steps[current].arrows, aspect: pitchAspect, reach: reach)
        arrowEdit.selected = index.map { .init(step: current, index: $0) }
    }

    private func dragBend(_ dot: Point, ended: Bool) {
        guard let index = selectedArrow else {
            arrowEdit.preview = nil
            return
        }
        guard ended else {
            arrowEdit.preview = dot
            return
        }
        arrowEdit.preview = nil
        bend(index, to: dot)
    }

    /// VoiceOver: one `Nudge.step` deeper or shallower on the side it bends to.
    private func adjustBend(_ more: Bool) {
        guard let index = selectedArrow, case let points = steps[current].arrows[index].points,
              let dot = ShapedPath.dot(of: points, bentBy: more ? Nudge.step : -Nudge.step, aspect: pitchAspect) else { return }
        bend(index, to: dot)
    }

    private func bend(_ index: Int, to dot: Point) {
        let kind = steps[current].arrows[index].kind.rawValue
        applyEdit("Bend \(kind)") { StrokeEdits.bend(arrow: index, to: dot, step: current, in: &$0) }
    }

    /// The row's Remove: the arrow goes (one undo step); the run it set out stays until redrawn.
    func removeSelectedArrow() {
        guard let index = selectedArrow else { return }
        let kind = steps[current].arrows[index].kind.rawValue
        applyEdit("Remove \(kind)") { StrokeEdits.removeArrow(at: index, step: current, in: &$0) }
        arrowEdit.selected = nil
    }
}
