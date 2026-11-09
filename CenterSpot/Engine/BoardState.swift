import Foundation

/// Everything the renderer needs to draw one instant of a move (SPEC §3). Produced only by `Timeline`.
struct BoardState: Sendable, Equatable {
    /// An arrow on screen at this instant, with how visible it is (0…1).
    struct VisibleArrow: Sendable, Equatable {
        var arrow: Arrow
        var opacity: Double
    }

    /// A zone, shape line or glow on screen at this instant (D-65), with how visible it is (0…1). A zone or heat that
    /// eases into the next step's mark of the same id is already moved part of the way; lines and rings name players,
    /// so they follow `positions`.
    struct VisibleMark: Sendable, Equatable {
        enum Shape: Sendable, Equatable {
            case zone(Zone)
            case line(ShapeLine)
            case glow(Glow)
        }

        var shape: Shape
        var opacity: Double

        var id: String {
            switch shape {
            case .zone(let zone): zone.id
            case .line(let line): line.id
            case .glow(let glow): glow.id
            }
        }
    }

    /// Every token's position, keyed by token id.
    var positions: [String: Point]
    /// Arrows with opacity above zero, in their step's order.
    var arrows: [VisibleArrow]
    /// The step whose hold or move contains this instant.
    var stepIndex: Int
    /// Marks with opacity above zero, in their step's order (zones, lines, glows).
    var marks: [VisibleMark] = []
    /// How far each ball sits at its carrier's feet (0…1), eased across a move so a pass glides off one player and
    /// onto the next. Empty while editing: the renderer works it out from distance.
    var carry: [String: Double] = [:]

    /// A shape line's corners at this instant: where its players are, in order (D-65: they follow the players).
    func corners(of line: ShapeLine) -> [Point] {
        line.tokens.compactMap { positions[$0] }
    }
}
