import SwiftUI

/// The pitch on screen: `BoardRenderer` inside a `Canvas` (D-07), the touch gestures, and one accessibility element
/// per token over it (SPEC §6, §8). It draws `state` and reports gestures; the board screen owns the edits.
struct BoardCanvas: View {
    let tactic: Tactic
    let state: BoardState
    let selection: String?
    var dimsUnselected = false
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

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let geometry = BoardGeometry(kind: tactic.pitch.kind, fitting: rect)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.withCGContext { cg in
                        BoardRenderer.draw(state: state, tactic: tactic, in: cg, rect: CGRect(origin: .zero, size: size),
                                           options: .init(selection: selection, dimsUnselected: dimsUnselected, showsLift: true))
                    }
                }
                .accessibilityElement()
                .accessibilityLabel("Pitch, step \(state.stepIndex + 1) of \(stepCount)")
                .accessibilityIdentifier("board.pitch")
                .contentShape(Rectangle())
                .gesture(dragGesture(geometry))
                .simultaneousGesture(SpatialTapGesture(count: 2).onEnded { value in
                    if let id = hit(value.location, geometry) { onDoubleTap(id) }
                })
                .simultaneousGesture(SpatialTapGesture(count: 1).onEnded { value in
                    onTap(hit(value.location, geometry))
                })

                accessibilityLayer(geometry)
            }
        }
    }

    private var stepCount: Int { tactic.phases.first?.steps.count ?? 1 }

    private func hit(_ location: CGPoint, _ geometry: BoardGeometry) -> String? {
        geometry.hitToken(at: location, positions: state.positions, tokens: tactic.tokens)
    }

    /// Moves the token under the finger, keeping the grab offset so the disc doesn't jump to the fingertip.
    private func dragGesture(_ geometry: BoardGeometry) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
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
    private func accessibilityLayer(_ geometry: BoardGeometry) -> some View {
        let centres = geometry.drawnCentres(positions: state.positions, tokens: tactic.tokens)
        let roles = Presets.shared.roles
        return ForEach(BoardRenderer.drawingOrder(tactic.tokens)) { token in
            if let centre = centres[token.id], let point = state.positions[token.id] {
                Color.clear
                    .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                    .position(centre)
                    .accessibilityElement()
                    .accessibilityLabel(Placement.label(for: token, in: tactic, stepIndex: state.stepIndex, roles: roles))
                    .accessibilityHint(token.kind == .player ? "Double-tap to edit" : "Double-tap to select")
                    .accessibilityIdentifier("board.token.\(token.id)")
                    .accessibilityAddTraits(selection == token.id ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction {
                        if token.kind == .player { onDoubleTap(token.id) } else { onTap(token.id) }
                    }
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        // SPEC §8: the adjustable action moves a token by `Nudge.step` of the pitch.
                        case .increment: onNudge(token.id, Nudge.up.applied(to: point))
                        case .decrement: onNudge(token.id, Nudge.down.applied(to: point))
                        @unknown default: break
                        }
                    }
                    .accessibilityAction(named: "Move left") { onNudge(token.id, Nudge.left.applied(to: point)) }
                    .accessibilityAction(named: "Move right") { onNudge(token.id, Nudge.right.applied(to: point)) }
            }
        }
        .allowsHitTesting(false)
    }
}
