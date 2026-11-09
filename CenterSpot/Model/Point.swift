import Foundation

/// A position in normalised pitch coordinates (D-05): `x` left → right, `y` from your own goal line (0)
/// to the opponent's (1). Never points or pixels; those exist only in `Render/`.
struct Point: Codable, Sendable, Hashable {
    var x: Double
    var y: Double

    /// The centre spot, where a token starts when step 1 doesn't place it (docs/FORMAT.md).
    static let centre = Point(x: 0.5, y: 0.5)

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The same point pulled inside the pitch (used on decode and on drag).
    var clamped: Point {
        Point(x: x.clamped(to: 0...1), y: y.clamped(to: 0...1))
    }

    /// Decoding refuses NaN and infinity and clamps everything else to 0…1 (docs/FORMAT.md, Coordinates).
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        guard x.isFinite, y.isFinite else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: container.codingPath, debugDescription: "Coordinates must be finite numbers.")
            )
        }
        self = Point(x: x, y: y).clamped
    }
}
