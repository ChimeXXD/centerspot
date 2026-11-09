import SwiftUI

/// The pitch on screen: `BoardRenderer` inside a `Canvas` (D-07), the touch gestures, and one accessibility element
/// per token over it (SPEC §6, §8). It draws `state` and reports gestures and drawn strokes; the board screen owns the
/// edits.
struct BoardCanvas: View {
    let tactic: Tactic
    let state: BoardState
    let selection: String?
    var dimsUnselected = false
    /// Reduce Motion playback: the next resting step laid over `state` at this opacity (`PlaybackTrack.frame`).
    var crossfade: (state: BoardState, mix: Double)?
    /// Playback through the broadcast camera (BR-2): the point it looks at. Nil is the flat board.
    var broadcast: Point?
    /// Reduce Motion: the still broadcast view fits this whole area (D-76).
    var broadcastSpan: CameraTrack.Span?
    /// The token the "Move a player" tip points at while editing (D-78), or nil.
    var dragTipToken: String?
    /// Dragging, double-tap and VoiceOver nudges move tokens; off while playing and while a finger draws.
    var movesTokens = true
    /// Which touches draw a stroke (SPEC §6), and the kind it draws, for the live line's colour.
    var strokeInput: StrokeInput = .pencil
    var strokeKind: Arrow.Kind = .run
    /// Draw mode (D-65): the selected mark (a zone shows its handles), the line being tapped out, and the dashed box
    /// under the finger while a zone is drawn, moved or resized.
    var selectedMark: String?
    var pendingLine: [String] = []
    var zonePreview: Zone?
    /// While a mark tool is picked: taps and drags on the pitch make marks instead of strokes.
    var marking: BoardMarking?
    /// Each mark is read out by VoiceOver; in draw mode these actions select, remove, move and resize them.
    var showsMarks = true
    var markActions: MarkActions?
    /// While an arrow tool is picked (D-72): taps select a bent arrow, and its middle dot drags its bend.
    var bending: BoardBending?
    /// A finished stroke: its points on the pitch (unclamped) and the token it started on (`strokeStart`).
    var onStroke: ([Point], String?) -> Void = { _, _ in }
    var onTap: (String?) -> Void
    var onDoubleTap: (String) -> Void
    /// Called while a token is dragged, with where it would land (unclamped; the edit clamps).
    var onDrag: (String, Point) -> Void
    var onDragEnd: (String, Point) -> Void
    /// A drag that was cancelled (it never ended) is dropped when the next one starts.
    var onDragCancel: () -> Void = {}
    /// VoiceOver nudges: the token and its new position.
    var onNudge: (String, Point) -> Void

    /// The token being dragged, the grab offset and where the drag began. A cancelled drag never reaches `onEnded`,
    /// so a drag that starts somewhere else replaces a stale one instead of moving its token.
    @State private var dragging: (id: String, offset: CGSize, start: CGPoint)?
    /// The stroke being drawn, in view points, and the token it started on.
    @State private var stroke: [CGPoint] = []
    @State private var strokeStart: String?
    /// A touch with a mark tool: where it began, and what kind of drag it became once it moved (nil: still a tap).
    @State var markTouch: (start: CGPoint, drag: BoardMarking.DragKind?)?
    /// The last tap a mark tool took, so a tap reported both as a short stroke and by the tap gesture counts once.
    @State var lastMarkTap: (time: ContinuousClock.Instant, at: CGPoint, viaStroke: Bool)?
    /// A touch on the bend dot: where it began, how far from the dot's centre it grabbed it, and whether it has left a
    /// tap's reach (a tap on the dot bends nothing).
    @State var bendTouch: (start: CGPoint, grab: CGSize, moved: Bool)?

    var body: some View {
        // Read on the main actor, outside the closures SwiftUI may call later (as `StepsList`, Chime's iPad, 8 Nov).
        let dragTip = dragTipToken == nil ? nil : Onboarding.shared.current(DragTip.self)
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let geometry = BoardGeometry(kind: tactic.pitch.kind, fitting: rect)
            let centres = tokenCentres(geometry, view: rect)
            ZStack(alignment: .topLeading) {
                // Under the pitch, so the drag it asks for reaches the pitch (an anchor that ignores touches never
                // shows its popover).
                dragTipAnchor(dragTip, centres)
                Canvas { context, size in
                    context.withCGContext { cg in
                        BoardRenderer.draw(state: state, crossfadingTo: crossfade?.state, mix: crossfade?.mix ?? 0,
                                           tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size),
                                           options: options)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Pitch, step \(state.stepIndex + 1) of \(stepCount)")
                .accessibilityIdentifier("board.pitch")
                .contentShape(Rectangle())
                .gesture(dragGesture(geometry), including: movesTokens ? .all : .none)
                .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                    if let id = hit(value.location, geometry) { onDoubleTap(id) }
                }, including: movesTokens ? .all : .none)
                .simultaneousGesture(SpatialTapGesture(count: 1).onEnded { value in
                    if let marking { markTap(value.location, geometry, marking, viaStroke: false) } else { onTap(hit(value.location, geometry)) }
                    bending?.onTap(geometry.normalised(value.location))
                })
                .gesture(StrokeCapture(input: strokeInput) { phase, location in capture(phase, location, geometry) })

                liveStroke
                zoneBox(geometry)
                bendDot(geometry)

                // Marks under the players, as drawn: a player on a zone or line is found by touch first.
                if showsMarks { markLayer(geometry) }
                accessibilityLayer(centres)
                playerTag(centres, geometry, in: rect)
                bendElement(geometry)
            }
        }
    }

    /// The stroke under the finger or Pencil, in its kind's colour (the mockup's draw screen). Screen only: what the
    /// stroke becomes is drawn by `BoardRenderer` once it ends.
    @ViewBuilder private var liveStroke: some View {
        if stroke.count > 1 {
            SwiftUI.Path { $0.addLines(stroke) }
                .stroke(ArrowDrawing.colour(for: strokeKind).color,
                        style: StrokeStyle(lineWidth: Tokens.Size.liveStroke, lineCap: .round, lineJoin: .round))
                .allowsHitTesting(false)
        }
    }

    private var options: BoardRenderer.Options {
        var options = BoardRenderer.Options(
            selection: strokeStart ?? selection, dimsUnselected: dimsUnselected, showsLift: true,
            selectedMark: selectedMark, pendingLine: pendingLine, broadcast: broadcast, broadcastSpan: broadcastSpan)
        options.onTop = dragging?.id
        return options
    }

    private func capture(_ phase: StrokeCapture.Phase, _ location: CGPoint, _ geometry: BoardGeometry) {
        if let marking {
            captureMark(phase, location, geometry, marking)
            return
        }
        if captureBend(phase, location, geometry) { return }
        switch phase {
        case .began:
            if dragging != nil { dragging = nil; onDragCancel() }
            stroke = [location]
            strokeStart = geometry.strokeStart(at: location, positions: state.positions, tokens: tactic.tokens)
        case .moved:
            if stroke.last != location { stroke.append(location) }
        case .ended:
            if stroke.last != location { stroke.append(location) }
            onStroke(stroke.map(geometry.normalised), strokeStart)
            tapArrow(stroke, geometry)
            stroke = []
            strokeStart = nil
        case .cancelled:
            stroke = []
            strokeStart = nil
        }
    }

    private var stepCount: Int { tactic.phases.first?.steps.count ?? 1 }

    func hit(_ location: CGPoint, _ geometry: BoardGeometry) -> String? {
        geometry.hitToken(at: location, positions: state.positions, tokens: tactic.tokens, selected: selection)
    }

    /// Moves the token under the finger, keeping the grab offset so the disc doesn't jump to the fingertip.
    private func dragGesture(_ geometry: BoardGeometry) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragBend(value, ended: false, geometry) { return }
                if dragging?.start != value.startLocation {
                    if dragging != nil { dragging = nil; onDragCancel() }
                    guard let id = hit(value.startLocation, geometry), let p = state.positions[id] else { return }
                    let centre = geometry.point(p)
                    dragging = (id, CGSize(width: value.startLocation.x - centre.x, height: value.startLocation.y - centre.y),
                                value.startLocation)
                }
                guard let dragging else { return }
                onDrag(dragging.id, landing(value.location, dragging.offset, geometry))
            }
            .onEnded { value in
                if dragBend(value, ended: true, geometry) { return }
                guard let dragging else { return }
                onDragEnd(dragging.id, landing(value.location, dragging.offset, geometry))
                self.dragging = nil
            }
    }

    private func landing(_ location: CGPoint, _ offset: CGSize, _ geometry: BoardGeometry) -> Point {
        geometry.normalised(CGPoint(x: location.x - offset.width, y: location.y - offset.height))
    }

    /// An invisible 44 pt element per token, labelled in football words from `Placement` (SPEC §8). It passes
    /// touches through to the canvas; VoiceOver and UI tests use it.
    /// Through the broadcast camera each element sits where the camera draws its disc, and a player the camera can't
    /// see has none, so VoiceOver never lands off the board or over the controls (review, 8 Nov).
    private func accessibilityLayer(_ centres: [String: CGPoint]) -> some View {
        let roles = Presets.shared.roles
        return ForEach(BoardRenderer.drawingOrder(tactic.tokens, selected: selection)) { token in
            if let centre = centres[token.id], let point = state.positions[token.id] {
                tokenElement(token, at: centre, point: point, roles: roles)
            }
        }
        .allowsHitTesting(false)
    }

    /// The tag over the tapped player (D-98): its name, else its position ("CDM", "LB"). Screen only, never in an
    /// export, and only while editing; it sits above the selection ring, or under the player near the top edge.
    @ViewBuilder private func playerTag(_ centres: [String: CGPoint], _ geometry: BoardGeometry, in view: CGRect) -> some View {
        if movesTokens, let id = selection, let centre = centres[id], let point = state.positions[id],
           let text = tactic.tokens.first(where: { $0.id == id })?.tag(at: point) {
            // Sized with the discs: the caption size on a phone, up to 18 pt on an iPad's big board.
            let size = min(max(geometry.tokenRadius * 0.55, 12), 18), pad = (size * 0.92).rounded()
            let reach = geometry.tokenRadius * 1.45 + Tokens.Space.s1
            Text(text)
                .font(.custom(Tokens.Typeface.uiName, size: size, relativeTo: .caption).weight(.bold))
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(1)
                .padding(.horizontal, pad * 0.75)
                .padding(.vertical, pad * 0.3)
                .background(Capsule().fill(Tokens.Colour.surface3.color))
                .padding(.horizontal, Tokens.Space.s1)
                // Placed by its measured size (the stack is top-leading), so Dynamic Type never pushes it onto the
                // disc, a player on the touchline keeps it on the board, and a long name truncates at the view's width.
                .alignmentGuide(.leading) { d in -min(max(centre.x - d.width / 2, 0), max(view.width - d.width, 0)) }
                .alignmentGuide(.top) { d in
                    let top = centre.y - reach - d.height
                    return -(top >= 0 ? top : centre.y + reach)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The "Move a player" tip's anchor (D-82): its own 44 pt view on the player, under the pitch. Hung on the token
    /// element, `position` stretched the anchor over the whole board and the arrow pointed at the bottom middle, where
    /// the keeper stands.
    @ViewBuilder private func dragTipAnchor(_ tip: DragTip?, _ centres: [String: CGPoint]) -> some View {
        if let id = dragTipToken, let tip, let centre = centres[id] {
            Color.clear
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .centerSpotTip(tip, arrowEdge: .top)
                .position(centre)
        }
    }

    /// Where each token is drawn, flat or through the broadcast camera; a token the camera can't see has none.
    private func tokenCentres(_ geometry: BoardGeometry, view: CGRect) -> [String: CGPoint] {
        let camera = BoardRenderer.camera(for: options, in: view, kind: tactic.pitch.kind)
        let flat = (camera?.plane ?? geometry).drawnCentres(positions: state.positions, tokens: tactic.tokens, carry: state.carry)
        let centres: [String: CGPoint]
        if let camera {
            centres = flat.mapValues { (p: CGPoint) -> CGPoint in camera.project(p) }.filter { view.contains($0.value) }
        } else {
            centres = flat
        }
        return centres
    }

    /// One token's element. Kept apart, with its traits typed, so Xcode 26.6's type checker finishes in time (CI).
    private func tokenElement(_ token: Token, at centre: CGPoint, point: Point, roles: [Role]) -> some View {
        let label = Placement.label(for: token, in: tactic, stepIndex: state.stepIndex, roles: roles)
        let hint = token.kind == .player ? "Double-tap to edit" : "Double-tap to select"
        let traits: AccessibilityTraits = selection == token.id ? [.isButton, .isSelected] : [.isButton]
        return Color.clear
            .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
            .position(centre)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityIdentifier("board.token.\(token.id)")
            .accessibilityAddTraits(traits)
            .accessibilityAction {
                // With a mark tool, activating a player taps it out for a line or puts rings on it (D-65).
                if let marking { marking.onTap(point, token.id); return }
                guard movesTokens else { return }
                if token.kind == .player { onDoubleTap(token.id) } else { onTap(token.id) }
            }
            .accessibilityAdjustableAction { direction in
                guard movesTokens else { return }
                switch direction {
                // SPEC §8: the adjustable action moves a token by `Nudge.step` of the pitch.
                case .increment: onNudge(token.id, Nudge.up.applied(to: point))
                case .decrement: onNudge(token.id, Nudge.down.applied(to: point))
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Move left") { if movesTokens { onNudge(token.id, Nudge.left.applied(to: point)) } }
            .accessibilityAction(named: "Move right") { if movesTokens { onNudge(token.id, Nudge.right.applied(to: point)) } }
    }
}
