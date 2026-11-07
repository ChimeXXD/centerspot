import Foundation

/// One VoiceOver nudge of a token (swipe up or down on an adjustable token, or the Move left / Move right actions).
enum Nudge: Sendable, CaseIterable {
    case up, down, left, right

    /// How far one nudge moves a token, as a fraction of the pitch.
    static let step = 0.02

    /// `p` moved one step this way, kept on the pitch (D-05).
    func applied(to p: Point) -> Point {
        let moved = switch self {
        case .up: Point(x: p.x, y: p.y + Self.step)
        case .down: Point(x: p.x, y: p.y - Self.step)
        case .left: Point(x: p.x - Self.step, y: p.y)
        case .right: Point(x: p.x + Self.step, y: p.y)
        }
        return Point(x: moved.x.clamped(to: 0...1), y: moved.y.clamped(to: 0...1))
    }
}
