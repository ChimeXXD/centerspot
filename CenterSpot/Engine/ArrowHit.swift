import Foundation

/// Which arrow a tap in Draw lands on (D-72), so its middle dot can be shown and dragged. Only arrows with a bend have
/// a dot (more than two points); a straight one is redrawn instead. Measured on the pitch in pitch widths (y scaled by
/// `aspect`), like `MarkHit`; the latest arrow wins, as it is drawn on top.
enum ArrowHit {
    /// The index of the bent arrow passing within `reach` of `p`.
    static func bendable(near p: Point, in arrows: [Arrow], aspect: Double, reach: Double) -> Int? {
        arrows.indices.last { i in
            let points = arrows[i].points
            guard points.count > 2 else { return false }
            return zip(points, points.dropFirst()).contains { MarkHit.segmentDistance(p, $0, $1, aspect: aspect) <= reach }
        }
    }
}
