import Foundation

/// Everything the renderer needs to draw one instant of a move (SPEC §3). Produced only by `Timeline`.
struct BoardState: Sendable, Equatable {
    /// An arrow on screen at this instant, with how visible it is (0…1).
    struct VisibleArrow: Sendable, Equatable {
        var arrow: Arrow
        var opacity: Double
    }

    /// Every token's position, keyed by token id.
    var positions: [String: Point]
    /// Arrows with opacity above zero, in their step's order.
    var arrows: [VisibleArrow]
    /// The step whose hold or move contains this instant.
    var stepIndex: Int
}
