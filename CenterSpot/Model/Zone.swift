import Foundation

/// A see-through box on the grass for one step (D-65), in normalised pitch units (D-05): `x`, `y` is the corner nearest
/// the left touchline and your own goal line, `w`, `h` its size. On read it is pulled inside the pitch and grown to at
/// least `minSize` each side (docs/FORMAT.md, repair).
struct Zone: Codable, Sendable, Hashable, Identifiable {
    /// The smallest box on either side, as a share of the pitch (the mockup's 4%).
    static let minSize = 0.04
    /// Slack for floating-point sums, so a repaired zone reads back unchanged.
    static let tolerance = 1e-9

    var id: String
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    /// A kit palette key; the default is lime (the accent).
    var colour: Side.Colour

    init(id: String, x: Double, y: Double, w: Double, h: Double, colour: Side.Colour = .lime) {
        self.id = id
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.colour = colour
    }

    /// The box between two corners, in any order (a drag from one to the other), clamped like a read.
    init(id: String, from a: Point, to b: Point, colour: Side.Colour = .lime) {
        self.init(id: id, x: a.x, y: a.y, w: b.x - a.x, h: b.y - a.y, colour: colour)
        self = clamped
    }

    /// Inside the pitch and at least `minSize` each side. A zone that already is comes back unchanged.
    var clamped: Zone {
        var zone = self
        (zone.x, zone.w) = Self.span(start: x, length: w)
        (zone.y, zone.h) = Self.span(start: y, length: h)
        return zone
    }

    var centre: Point { Point(x: x + w / 2, y: y + h / 2) }

    /// Whether `p` is on the box, edges included.
    func contains(_ p: Point) -> Bool {
        p.x >= x && p.x <= x + w && p.y >= y && p.y <= y + h
    }

    /// One axis: a negative length runs backwards from `start`; the span is cut to 0…1, then grown about its middle
    /// to `minSize` if it is smaller.
    static func span(start: Double, length: Double) -> (start: Double, length: Double) {
        let lo = min(start, start + length), size = abs(length)
        if lo >= 0, size >= minSize - tolerance, lo + size <= 1 + tolerance { return (lo, size) }
        var low = lo.clamped(to: 0...1), high = max(start, start + length).clamped(to: 0...1)
        if high - low < minSize {
            let middle = ((low + high) / 2).clamped(to: minSize / 2 ... 1 - minSize / 2)
            low = middle - minSize / 2
            high = low + minSize
        }
        return (low, high - low)
    }

    private enum CodingKeys: String, CodingKey {
        case id, x, y, w, h, colour
    }

    /// NaN or infinity refuses the file (like a coordinate); an unknown colour falls back to lime.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        w = try container.decode(Double.self, forKey: .w)
        h = try container.decode(Double.self, forKey: .h)
        colour = (try? container.decodeIfPresent(Side.Colour.self, forKey: .colour)) ?? .lime
        guard [x, y, w, h].allSatisfy(\.isFinite) else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "A zone needs finite numbers."))
        }
        self = clamped
    }
}
