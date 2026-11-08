import SwiftUI

/// Draw › Zone, Line and Glow (D-65, mockup draw--tools): each finished mark is one undoable `MarkEdits` edit through
/// `applyEdit`, so Cancel takes the whole session back (D-62) and an edit that would overflow the file is refused (D-69).
extension BoardScreen {
    /// Touches make marks only while a mark tool is picked.
    var boardMarking: BoardMarking? {
        guard mode == .drawing, drawTool.drawsMarks else { return nil }
        return BoardMarking(onTap: markTap, onDrag: markDrag, onCancelDrag: { zonePreview = nil })
    }

    var markActions: MarkActions {
        MarkActions(
            select: { id in selectedMark = id },
            remove: { id in removeMark(id) },
            moveZone: { id, nudge in nudgeZone(id, nudge) },
            resizeZone: { id, corner, grow in resizeZoneStep(id, corner, grow: grow) }
        )
    }

    /// "Zone 1 · step 4" while a mark on this step is selected; nil once it's gone (removed, or undone).
    var selectedMarkLabel: String? {
        selectedMark.flatMap { Placement.rowLabel(forMark: $0, in: tactic, stepIndex: current) }
    }

    private var currentMarks: Marks {
        steps.indices.contains(current) ? steps[current].marks : Marks()
    }

    private var aspect: Double { tactic.pitch.kind.size.length / tactic.pitch.kind.size.width }

    /// Clears Draw's selection: the mark, the line being tapped out, the zone under the finger, and the selected arrow.
    func clearMarkState() {
        selectedMark = nil
        lineDraft.clear()
        zonePreview = nil
        clearArrowState()
    }

    /// Picking another tool finishes a line being tapped out (mockup draw.kind.line) and clears the selection.
    func changeTool() {
        finishLine()
        clearMarkState()
    }

    // MARK: Taps

    func markTap(_ point: Point, _ tokenID: String?) {
        let token = tactic.tokens.first { $0.id == tokenID }
        switch drawTool {
        case .zone:
            selectedMark = MarkHit.zone(at: point, in: currentMarks)
        case .line:
            tapLine(point, token?.kind == .player ? tokenID : nil)
        case .glow:
            if let token, token.kind == .player {
                add("Add glow") { MarkEdits.addRings(on: token.id, step: current, in: &$0) }
            } else if let heat = MarkHit.heat(at: point, in: currentMarks, aspect: aspect) {
                selectedMark = heat
            } else {
                add("Add glow") { MarkEdits.addHeat(at: point, step: current, in: &$0) }
            }
        case .run, .pass, .dribble, .press:
            break
        }
    }

    private func tapLine(_ point: Point, _ playerID: String?) {
        switch lineDraft.tap(playerID, in: tactic) {
        case .started: selectedMark = nil
        case .added: break
        case .finished: finishLine()
        case .otherSide: show("One side per line")
        case .ignored:
            // A tap on the grass beside a line selects it, so it can be removed (no line is being tapped out).
            guard lineDraft.isEmpty, playerID == nil else { return }
            let reach = boardWidth > 0 ? Double(Tokens.Size.touch / 2 / boardWidth) : 0.04
            let positions = Timeline.restingState(step: current, in: tactic).positions
            selectedMark = MarkHit.line(near: point, in: currentMarks, positions: positions, aspect: aspect, reach: reach)
        }
    }

    /// Commits the line being tapped out if it joins two players or more; a single tap leaves nothing.
    func finishLine() {
        let tokens = lineDraft.tokens
        lineDraft.clear()
        guard tokens.count >= ShapeLine.minTokens else { return }
        add("Draw line") { MarkEdits.addLine(tokens, step: current, in: &$0) }
    }

    // MARK: Zone drags

    func markDrag(_ drag: BoardMarking.Drag, ended: Bool) {
        guard drawTool == .zone else { return }
        guard ended else {
            zonePreview = preview(drag)
            return
        }
        zonePreview = nil
        switch drag.kind {
        case .new:
            add("Draw zone", selectsIt: true) { MarkEdits.addZone(from: drag.start, to: drag.current, step: current, in: &$0) }
        case .move(let id):
            applyEdit("Move zone") {
                MarkEdits.moveZone(id, by: drag.current.x - drag.start.x, drag.current.y - drag.start.y, step: current, in: &$0)
            }
        case .resize(let id, let corner):
            applyEdit("Resize zone") { MarkEdits.resizeZone(id, corner: corner, to: drag.current, step: current, in: &$0) }
        }
    }

    /// What the zone would be if the finger lifted now: the same edit on a copy.
    private func preview(_ drag: BoardMarking.Drag) -> Zone? {
        var copy = tactic
        let id: String
        switch drag.kind {
        case .new:
            // The real add, so a box too small to keep (or a full step) shows nothing, as lifting would make nothing.
            guard case .added(let zone) = MarkEdits.addZone(from: drag.start, to: drag.current, step: current, in: &copy)
            else { return nil }
            id = zone
        case .move(let zone):
            MarkEdits.moveZone(zone, by: drag.current.x - drag.start.x, drag.current.y - drag.start.y, step: current, in: &copy)
            id = zone
        case .resize(let zone, let corner):
            MarkEdits.resizeZone(zone, corner: corner, to: drag.current, step: current, in: &copy)
            id = zone
        }
        guard let steps = copy.phases.first?.steps, steps.indices.contains(current) else { return nil }
        return steps[current].marks.zones.first { $0.id == id }
    }

    // MARK: Removing, and VoiceOver's moves

    func removeSelectedMark() {
        if let selectedMark { removeMark(selectedMark) }
    }

    func removeMark(_ id: String) {
        let kind = currentMarks.zones.contains { $0.id == id } ? "zone" : currentMarks.lines.contains { $0.id == id } ? "line" : "glow"
        applyEdit("Remove \(kind)") { MarkEdits.remove(id, step: current, in: &$0) }
        if selectedMark == id { selectedMark = nil }
    }

    private func nudgeZone(_ id: String, _ nudge: Nudge) {
        let moved = nudge.applied(to: Point(x: 0.5, y: 0.5))
        applyEdit("Move zone") { MarkEdits.moveZone(id, by: moved.x - 0.5, moved.y - 0.5, step: current, in: &$0) }
    }

    /// One nudge outward (grow) or inward (shrink) from a corner, for VoiceOver's adjustable handles.
    private func resizeZoneStep(_ id: String, _ corner: MarkEdits.Corner, grow: Bool) {
        guard let zone = currentMarks.zones.first(where: { $0.id == id }) else { return }
        let step = grow ? Nudge.step : -Nudge.step
        let right = corner == .topRight || corner == .bottomRight, top = corner == .topLeft || corner == .topRight
        let x = right ? zone.x + zone.w + step : zone.x - step
        let y = top ? zone.y + zone.h + step : zone.y - step
        applyEdit("Resize zone") { MarkEdits.resizeZone(id, corner: corner, to: Point(x: x, y: y), step: current, in: &$0) }
    }

    /// Runs an add as one undoable edit; a new zone is selected (mockup draw.zone), rings already there are selected
    /// instead of added twice, and a full step says so.
    private func add(_ actionName: String, selectsIt: Bool = false, _ edit: (inout Tactic) -> MarkEdits.Result) {
        var result = MarkEdits.Result.invalid
        guard applyEdit(actionName, { result = edit(&$0) }) else { return }
        switch result {
        case .added(let id): selectedMark = selectsIt ? id : nil
        case .existing(let id): selectedMark = id
        case .full: show("A step shows up to \(Marks.maxCount) zones, lines and glows.")
        case .tooSmall, .invalid: break
        }
    }
}
