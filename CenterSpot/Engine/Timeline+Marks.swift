import Foundation

/// Marks on the timeline (D-65), as pure as the rest of it (D-06). A step's marks fade in and out like its arrows
/// (D-46: in over the first `arrowFade` of its hold, out over the last `arrowFade` of its move; the last step's stay). A
/// mark that the next step carries on (`continues`) never fades: it shows throughout and a zone or heat eases into its
/// next shape with the players' move, while lines and rings follow the players by naming them.
extension Timeline {
    /// The marks of `steps[index]` at an instant: `fadeIn` is the time since the step began, `progress` the eased share
    /// of its move (nil while holding), `fadeOut` the time left in the move.
    static func visibleMarks(of steps: [Step], index: Int, sinceStart: Double, progress: Double?,
                             untilEnd: Double) -> [BoardState.VisibleMark] {
        guard steps.indices.contains(index) else { return [] }
        let previous = index > 0 ? shapes(of: steps[index - 1]) : []
        let next = index + 1 < steps.count ? shapes(of: steps[index + 1]) : []
        var visible: [BoardState.VisibleMark] = []
        for shape in shapes(of: steps[index]) {
            if let progress {
                if let later = next.first(where: { continues(shape, into: $0) }) {
                    visible.append(.init(shape: blend(shape, later, progress), opacity: 1))
                } else {
                    let opacity = min(1, untilEnd / arrowFade)
                    if opacity > 0 { visible.append(.init(shape: shape, opacity: opacity)) }
                }
            } else {
                let opacity = previous.contains { continues($0, into: shape) } ? 1 : min(1, sinceStart / arrowFade)
                if opacity > 0 { visible.append(.init(shape: shape, opacity: opacity)) }
            }
        }
        return visible
    }

    /// A step's marks fully shown, as the editor draws them.
    static func restingMarks(of step: Step) -> [BoardState.VisibleMark] {
        shapes(of: step).map { .init(shape: $0, opacity: 1) }
    }

    /// Zones, then lines, then glows.
    static func shapes(of step: Step) -> [BoardState.VisibleMark.Shape] {
        step.marks.zones.map { .zone($0) } + step.marks.lines.map { .line($0) } + step.marks.glows.map { .glow($0) }
    }

    /// Whether `b` on the next step is `a` carried on: the same id and kind, a zone in the same colour, a line joining
    /// the same players, rings on the same player, or heat anywhere. Anything else fades out and the new one fades in.
    static func continues(_ a: BoardState.VisibleMark.Shape, into b: BoardState.VisibleMark.Shape) -> Bool {
        switch (a, b) {
        case let (.zone(x), .zone(y)): x.id == y.id && x.colour == y.colour
        case let (.line(x), .line(y)): x.id == y.id && x.tokens == y.tokens
        case let (.glow(x), .glow(y)):
            switch (x.target, y.target) {
            case let (.token(p), .token(q)): x.id == y.id && p == q
            case (.spot, .spot): x.id == y.id
            default: false
            }
        default: false
        }
    }

    /// `a` moved `progress` of the way to `b` (a continuing mark): a zone's box and a heat's spot and size ease; lines
    /// and rings are the same mark either way.
    static func blend(_ a: BoardState.VisibleMark.Shape, _ b: BoardState.VisibleMark.Shape,
                      _ progress: Double) -> BoardState.VisibleMark.Shape {
        func mix(_ u: Double, _ v: Double) -> Double { u + (v - u) * progress }
        switch (a, b) {
        case let (.zone(x), .zone(y)):
            return .zone(Zone(id: x.id, x: mix(x.x, y.x), y: mix(x.y, y.y), w: mix(x.w, y.w), h: mix(x.h, y.h), colour: x.colour))
        case let (.glow(x), .glow(y)):
            guard case let .spot(p, r) = x.target, case let .spot(q, s) = y.target else { return a }
            return .glow(Glow(id: x.id, target: .spot(Point(x: mix(p.x, q.x), y: mix(p.y, q.y)), radius: mix(r, s))))
        default:
            return a
        }
    }
}
