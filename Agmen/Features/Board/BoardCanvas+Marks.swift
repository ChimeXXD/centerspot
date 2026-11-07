import SwiftUI

/// The board's marks on screen (D-65): touches with a mark tool, the dashed box under the finger, and one VoiceOver
/// element per mark ("Zone 1, left wing, step 4"), with the selected zone's corner handles in draw mode.
extension BoardCanvas {
    /// A touch that moves less than this is a tap.
    static let tapSlop: CGFloat = 10
    /// One touch can be reported twice, as a short stroke and by the tap gesture (which may wait out a double tap): the
    /// second report, from the other route within this long and this near, is the same tap. Two taps by the same route
    /// always count, so tapping the last player again finishes a line however quick it is.
    static let tapEcho: Duration = .milliseconds(500)
    static let tapEchoDistance: CGFloat = 24

    // MARK: Touches

    func captureMark(_ phase: StrokeCapture.Phase, _ location: CGPoint, _ geometry: BoardGeometry, _ marking: BoardMarking) {
        switch phase {
        case .began:
            markTouch = (location, nil)
        case .moved:
            guard var touch = markTouch else { return }
            if touch.drag == nil, hypot(location.x - touch.start.x, location.y - touch.start.y) > Self.tapSlop {
                touch.drag = dragKind(startingAt: touch.start, geometry)
                markTouch = touch
            }
            if let kind = touch.drag { marking.onDrag(drag(kind, touch.start, location, geometry), false) }
        case .ended:
            guard let touch = markTouch else { return }
            markTouch = nil
            if let kind = touch.drag {
                marking.onDrag(drag(kind, touch.start, location, geometry), true)
            } else {
                markTap(touch.start, geometry, marking, viaStroke: true)
            }
        case .cancelled:
            if markTouch?.drag != nil { marking.onCancelDrag() }
            markTouch = nil
        }
    }

    func markTap(_ location: CGPoint, _ geometry: BoardGeometry, _ marking: BoardMarking, viaStroke: Bool) {
        let now = ContinuousClock.now
        if let last = lastMarkTap, last.viaStroke != viaStroke, now - last.time < Self.tapEcho,
           hypot(location.x - last.at.x, location.y - last.at.y) < Self.tapEchoDistance { return }
        lastMarkTap = (now, location, viaStroke)
        marking.onTap(geometry.normalised(location), hit(location, geometry))
    }

    private func drag(_ kind: BoardMarking.DragKind, _ start: CGPoint, _ current: CGPoint, _ g: BoardGeometry) -> BoardMarking.Drag {
        BoardMarking.Drag(kind: kind, start: g.normalised(start), current: g.normalised(current))
    }

    /// On a handle of the selected zone it resizes from that corner, inside it moves it, anywhere else it draws a new one.
    private func dragKind(startingAt start: CGPoint, _ g: BoardGeometry) -> BoardMarking.DragKind {
        guard let zone = selectedZone else { return .new }
        let box = MarkDrawing.rect(of: zone, g: g)
        let nearest = MarkEdits.Corner.allCases.map { ($0, Self.point(of: $0, in: box)) }
            .min { hypot($0.1.x - start.x, $0.1.y - start.y) < hypot($1.1.x - start.x, $1.1.y - start.y) }
        if let (corner, p) = nearest, hypot(p.x - start.x, p.y - start.y) <= BoardGeometry.hitRadius {
            return .resize(zone.id, corner)
        }
        return box.contains(start) ? .move(zone.id) : .new
    }

    private var selectedZone: Zone? {
        for mark in state.marks where mark.id == selectedMark {
            if case .zone(let zone) = mark.shape { return zone }
        }
        return nil
    }

    static func point(of corner: MarkEdits.Corner, in box: CGRect) -> CGPoint {
        switch corner {
        case .topLeft: CGPoint(x: box.minX, y: box.minY)
        case .topRight: CGPoint(x: box.maxX, y: box.minY)
        case .bottomLeft: CGPoint(x: box.minX, y: box.maxY)
        case .bottomRight: CGPoint(x: box.maxX, y: box.maxY)
        }
    }

    /// The box under the finger while a zone is drawn, moved or resized: dashed, screen only (mockup draw.zone). What it
    /// becomes is drawn by `BoardRenderer` once the finger lifts.
    @ViewBuilder func zoneBox(_ g: BoardGeometry) -> some View {
        if let zonePreview {
            SwiftUI.Path(MarkDrawing.rect(of: zonePreview, g: g))
                .stroke(Tokens.Colour.zoneStroke.color, style: StrokeStyle(lineWidth: 1.6, dash: [5, 4]))
                .allowsHitTesting(false)
        }
    }

    // MARK: VoiceOver

    /// One element per mark on the board, and the selected zone's four handles in draw mode.
    func markLayer(_ g: BoardGeometry) -> some View {
        let elements = markElements(g)
        // Typed and split so the older CI compiler type-checks it in time.
        var handles: [(MarkEdits.Corner, String, CGPoint)] = []
        if markActions != nil, let zone = selectedZone {
            let rect = MarkDrawing.rect(of: zone, g: g)
            handles = MarkEdits.Corner.allCases.map { ($0, zone.id, Self.point(of: $0, in: rect)) }
        }
        return ZStack(alignment: .topLeading) {
            ForEach(elements) { markElement($0) }
            ForEach(handles, id: \.0) { handle in handleElement(handle.0, zone: handle.1, at: handle.2) }
        }
        .allowsHitTesting(false)
    }

    struct MarkElement: Identifiable {
        let id: String
        let identifier: String
        let label: String
        let frame: CGRect
        let isZone: Bool
    }

    private func markElements(_ g: BoardGeometry) -> [MarkElement] {
        let centres = g.drawnCentres(positions: state.positions, tokens: tactic.tokens, carry: state.carry)
        let prefix = markActions == nil ? "board" : "draw"
        var counts: [String: Int] = [:]
        var elements: [MarkElement] = []
        for mark in state.marks {
            let kind: String, frame: CGRect
            switch mark.shape {
            case .zone(let zone):
                (kind, frame) = ("zone", MarkDrawing.rect(of: zone, g: g))
            case .line(let line):
                (kind, frame) = ("line", Self.bounds(line.tokens.compactMap { centres[$0] }))
            case .glow(let glow):
                switch glow.target {
                case .token(let id): (kind, frame) = ("glow", Self.bounds([centres[id]].compactMap { $0 }))
                case let .spot(centre, radius):
                    let c = g.point(centre), r = CGFloat(radius) * g.pitchRect.width
                    (kind, frame) = ("glow", CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                }
            }
            counts[kind, default: 0] += 1
            guard let label = Placement.label(forMark: mark.id, in: tactic, stepIndex: state.stepIndex) else { continue }
            let touch = Tokens.Size.touch
            let sized = frame.insetBy(dx: min(0, (frame.width - touch) / 2), dy: min(0, (frame.height - touch) / 2))
            elements.append(MarkElement(id: mark.id, identifier: "\(prefix).\(kind).\(counts[kind] ?? 1)", label: label,
                                        frame: sized, isZone: kind == "zone"))
        }
        return elements
    }

    private static func bounds(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    /// Kept apart, with its traits typed, so Xcode 26.6's type checker finishes in time (CI).
    private func markElement(_ element: MarkElement) -> some View {
        let traits: AccessibilityTraits = selectedMark == element.id ? [.isButton, .isSelected] : [.isButton]
        return Color.clear
            .frame(width: element.frame.width, height: element.frame.height)
            .position(x: element.frame.midX, y: element.frame.midY)
            .accessibilityElement()
            .accessibilityLabel(element.label)
            .accessibilityIdentifier(element.identifier)
            .accessibilityAddTraits(markActions == nil ? [] : traits)
            .modifier(MarkElementActions(mark: element.id, isZone: element.isZone, actions: markActions))
    }

    private func handleElement(_ corner: MarkEdits.Corner, zone: String, at p: CGPoint) -> some View {
        let actions = markActions
        return Color.clear
            .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
            .position(p)
            .accessibilityElement()
            .accessibilityLabel("Zone corner, \(Self.words(corner))")
            .accessibilityHint("Swipe up to grow the zone, down to shrink it")
            .accessibilityIdentifier("draw.zone.handle.\(corner.rawValue)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: actions?.resizeZone(zone, corner, true)
                case .decrement: actions?.resizeZone(zone, corner, false)
                @unknown default: break
                }
            }
    }

    /// "top left", as the mockup's handle labels say.
    static func words(_ corner: MarkEdits.Corner) -> String {
        switch corner {
        case .topLeft: "top left"
        case .topRight: "top right"
        case .bottomLeft: "bottom left"
        case .bottomRight: "bottom right"
        }
    }
}

/// Draw mode's actions on a mark: activate selects it, Remove takes it off the step, and a zone moves like a token's
/// nudges (SPEC §8). Outside draw mode a mark is only read out.
private struct MarkElementActions: ViewModifier {
    let mark: String
    let isZone: Bool
    let actions: MarkActions?

    func body(content: Content) -> some View {
        if let actions, isZone {
            selectable(content, actions)
                .accessibilityAction(named: "Move up") { actions.moveZone(mark, .up) }
                .accessibilityAction(named: "Move down") { actions.moveZone(mark, .down) }
                .accessibilityAction(named: "Move left") { actions.moveZone(mark, .left) }
                .accessibilityAction(named: "Move right") { actions.moveZone(mark, .right) }
        } else if let actions {
            selectable(content, actions)
        } else {
            content
        }
    }

    private func selectable(_ content: Content, _ actions: MarkActions) -> some View {
        content
            .accessibilityAction { actions.select(mark) }
            .accessibilityAction(named: "Remove") { actions.remove(mark) }
    }
}
