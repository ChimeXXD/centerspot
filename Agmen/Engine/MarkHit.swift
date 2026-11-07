import Foundation

/// Which mark a tap in Draw lands on (D-65), measured on the pitch in pitch widths (y scaled by `aspect`, the pitch's
/// length over its width) so a reach looks the same both ways. The latest mark wins, as it is drawn on top.
enum MarkHit {
    /// The zone under `p`.
    static func zone(at p: Point, in marks: Marks) -> String? {
        marks.zones.last { $0.contains(p) }?.id
    }

    /// The heat whose glow covers `p`.
    static func heat(at p: Point, in marks: Marks, aspect: Double) -> String? {
        marks.glows.last { glow in
            guard case let .spot(centre, radius) = glow.target else { return false }
            return distance(p, centre, aspect: aspect) <= radius
        }?.id
    }

    /// The line passing within `reach` of `p`, its corners where `positions` puts the players.
    static func line(near p: Point, in marks: Marks, positions: [String: Point], aspect: Double, reach: Double) -> String? {
        marks.lines.last { line in
            let corners = line.tokens.compactMap { positions[$0] }
            return zip(corners, corners.dropFirst()).contains { segmentDistance(p, $0, $1, aspect: aspect) <= reach }
        }?.id
    }

    static func distance(_ a: Point, _ b: Point, aspect: Double) -> Double {
        hypot(a.x - b.x, (a.y - b.y) * aspect)
    }

    /// From `p` to the nearest point of the segment `a`–`b`.
    static func segmentDistance(_ p: Point, _ a: Point, _ b: Point, aspect: Double) -> Double {
        let (ax, ay, bx, by, px, py) = (a.x, a.y * aspect, b.x, b.y * aspect, p.x, p.y * aspect)
        let dx = bx - ax, dy = by - ay, lengthSquared = dx * dx + dy * dy
        let t = lengthSquared > 0 ? (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamped(to: 0...1) : 0
        return hypot(px - (ax + t * dx), py - (ay + t * dy))
    }
}
