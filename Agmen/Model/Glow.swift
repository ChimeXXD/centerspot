import Foundation

/// A glow on one step (D-65): rings under a player that follow them, or heat on a spot of the grass. In the file it is
/// `{ "id", "token" }` or `{ "id", "x", "y", "r" }` (docs/FORMAT.md).
struct Glow: Codable, Sendable, Hashable, Identifiable {
    enum Target: Sendable, Hashable {
        /// Rings under this player.
        case token(String)
        /// Heat centred here; `radius` is a share of the pitch's width.
        case spot(Point, radius: Double)
    }

    /// Heat radius, as a share of the pitch width (docs/FORMAT.md: clamped on read).
    static let radiusRange = 0.03...0.25
    /// A heat glow's radius when the file leaves it out, and the size a tap on the grass makes (the mockup's 0.11).
    static let defaultRadius = 0.11

    var id: String
    var target: Target

    init(id: String, target: Target) {
        self.id = id
        self.target = target
    }

    var tokenID: String? {
        if case .token(let id) = target { id } else { nil }
    }

    private enum CodingKeys: String, CodingKey {
        case id, token, x, y, r
    }

    /// `token` makes rings; otherwise `x`, `y` (and optionally `r`) make heat. Neither, or a NaN, refuses the file.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            target = .token(token)
            return
        }
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        let r = try container.decodeIfPresent(Double.self, forKey: .r) ?? Self.defaultRadius
        guard x.isFinite, y.isFinite, r.isFinite else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "A glow needs finite numbers."))
        }
        target = .spot(Point(x: x, y: y).clamped, radius: r.clamped(to: Self.radiusRange))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        switch target {
        case .token(let token):
            try container.encode(token, forKey: .token)
        case .spot(let centre, let radius):
            try container.encode(centre.x, forKey: .x)
            try container.encode(centre.y, forKey: .y)
            try container.encode(radius, forKey: .r)
        }
    }
}
