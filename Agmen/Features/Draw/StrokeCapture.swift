import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Which touches draw on the board (SPEC §6): Apple Pencil always; a finger only in iPhone draw mode.
enum StrokeInput: Sendable, Equatable {
    case none, pencil, fingerAndPencil
}

/// Captures one drawn stroke from the touch that lands on the board (D-08: capture only; the stroke becomes our own
/// path, never a `PKDrawing`). It begins on touch-down, so a Pencil stroke wins over the board's drag; finger touches
/// aren't even delivered to it unless the finger draws, so dragging tokens is unaffected.
final class StrokeGestureRecognizer: UIGestureRecognizer {
    var input: StrokeInput = .pencil {
        didSet {
            // Disabling cancels a stroke in flight, so one drawn across a mode change (Cancel, Done) isn't kept.
            isEnabled = false
            isEnabled = input != .none
            let types: [UITouch.TouchType] = input == .fingerAndPencil ? [.direct, .pencil] : [.pencil]
            allowedTouchTypes = types.map { NSNumber(value: $0.rawValue) }
        }
    }

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // One finger or one Pencil draws; a second touch on this recognizer is a different gesture. Only its own
        // touches count: `allTouches` holds every touch in the window, so a resting palm or a finger moving a token
        // on iPad would stop every Pencil stroke.
        guard state == .possible, touches.count == 1, (event.touches(for: self)?.count ?? 1) == 1 else {
            if state == .began || state == .changed { state = .cancelled } else { state = .failed }
            return
        }
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = state == .possible ? .failed : .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }
}

/// The recognizer in SwiftUI: reports each stroke point in the board's own coordinates.
struct StrokeCapture: UIGestureRecognizerRepresentable {
    enum Phase { case began, moved, ended, cancelled }

    var input: StrokeInput
    var onStroke: (Phase, CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> StrokeGestureRecognizer {
        StrokeGestureRecognizer(target: nil, action: nil)
    }

    func updateUIGestureRecognizer(_ recognizer: StrokeGestureRecognizer, context: Context) {
        if recognizer.input != input { recognizer.input = input }
    }

    func handleUIGestureRecognizerAction(_ recognizer: StrokeGestureRecognizer, context: Context) {
        let location = context.converter.localLocation
        switch recognizer.state {
        case .began: onStroke(.began, location)
        case .changed: onStroke(.moved, location)
        case .ended: onStroke(.ended, location)
        case .cancelled, .failed: onStroke(.cancelled, location)
        default: break
        }
    }
}
