import SwiftUI

/// The selected arrow's middle dot on screen (D-72): drawn as the zone handles are, dragged by a touch that starts on
/// it (a finger or Pencil stroke on iPhone, the finger's drag on iPad), and one VoiceOver element that bends it.
extension BoardCanvas {
    /// The dot, drawn over the board with the same handle drawing as a zone's corners. Screen only.
    @ViewBuilder func bendDot(_ g: BoardGeometry) -> some View {
        if let dot = bending?.dot {
            Canvas { context, _ in
                context.withCGContext { MarkDrawing.handles(at: [g.point(dot)], scale: g.scale, ctx: $0) }
            }
            .allowsHitTesting(false)
        }
    }

    /// Whether a touch at `location` grabs the dot: within reach of it, and nearer it than any token under the touch.
    private func grabs(_ location: CGPoint, _ g: BoardGeometry) -> CGSize? {
        guard let dot = bending?.dot else { return nil }
        let p = g.point(dot), d = hypot(location.x - p.x, location.y - p.y)
        guard d <= BoardGeometry.hitRadius else { return nil }
        if let id = hit(location, g), let token = state.positions[id] {
            let c = g.point(token)
            if hypot(location.x - c.x, location.y - c.y) < d { return nil }
        }
        return CGSize(width: location.x - p.x, height: location.y - p.y)
    }

    private func dot(at location: CGPoint, grab: CGSize, _ g: BoardGeometry) -> Point {
        g.normalised(CGPoint(x: location.x - grab.width, y: location.y - grab.height))
    }

    /// A stroke's touch: true when it is (or starts) a drag of the dot, so it draws nothing.
    func captureBend(_ phase: StrokeCapture.Phase, _ location: CGPoint, _ g: BoardGeometry) -> Bool {
        guard let bending else { return false }
        if phase == .began {
            bendTouch = grabs(location, g).map { (location, $0, false) }
            return bendTouch != nil
        }
        guard var touch = bendTouch else { return false }
        // A touch that never leaves a tap's reach is a tap on the dot: committing it would add an undo step for a
        // bend that didn't change (or refit an older freehand arrow).
        if !touch.moved, hypot(location.x - touch.start.x, location.y - touch.start.y) > Self.tapSlop {
            touch.moved = true
            bendTouch = touch
        }
        switch phase {
        case .began, .moved:
            if touch.moved { bending.onDrag(dot(at: location, grab: touch.grab, g), false) }
        case .ended:
            if touch.moved { bending.onDrag(dot(at: location, grab: touch.grab, g), true) } else { bending.onCancel() }
            bendTouch = nil
        case .cancelled:
            bending.onCancel()
            bendTouch = nil
        }
        return true
    }

    /// A stroke that stayed within a tap's reach is a tap on the arrows too: the tap gesture doesn't always fire once the
    /// stroke recognizer has taken the touch. Reported twice it selects the same arrow, so that's harmless.
    func tapArrow(_ stroke: [CGPoint], _ g: BoardGeometry) {
        guard let bending, let first = stroke.first,
              stroke.allSatisfy({ hypot($0.x - first.x, $0.y - first.y) <= Self.tapSlop }) else { return }
        bending.onTap(g.normalised(first))
    }

    /// The finger's drag on iPad (the Pencil draws): true when it drags the dot, so it moves no token. A drag that
    /// starts somewhere else replaces a stale one (a cancelled drag never ends).
    func dragBend(_ value: DragGesture.Value, ended: Bool, _ g: BoardGeometry) -> Bool {
        guard let bending else { return false }
        if bendTouch?.start != value.startLocation {
            if bendTouch != nil { bending.onCancel() }
            bendTouch = ended ? nil : grabs(value.startLocation, g).map { (value.startLocation, $0, true) }
        }
        guard let touch = bendTouch else { return false }
        bending.onDrag(dot(at: value.location, grab: touch.grab, g), ended)
        if ended { bendTouch = nil }
        return true
    }

    /// The dot for VoiceOver and UI tests: "Bend of 3's run. Drag to change the curve.", swipe up or down to bend.
    @ViewBuilder func bendElement(_ g: BoardGeometry) -> some View {
        if let bending, let dot = bending.dot {
            Color.clear
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .position(g.point(dot))
                .accessibilityElement()
                .accessibilityLabel(bending.label)
                .accessibilityHint("Swipe up to bend it more, down to bend it less")
                .accessibilityIdentifier("draw.bend.handle")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: bending.onAdjust(true)
                    case .decrement: bending.onAdjust(false)
                    @unknown default: break
                    }
                }
                .allowsHitTesting(false)
        }
    }
}
