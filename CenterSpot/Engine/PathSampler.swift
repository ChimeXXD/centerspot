import Foundation

/// Finds the point a given fraction of the way along a run, by arc length (SPEC §3).
enum PathSampler {
    /// The point at `fraction` (clamped to 0…1) of the path's length.
    ///
    /// Length is measured in metres on the pitch, not in normalised units: one unit of `x` is the pitch
    /// width and one unit of `y` its length, so on a full pitch a step up the pitch covers 105/68 times
    /// more ground than the same step across it. Measuring in normalised units would make a runner speed
    /// up whenever the run turns across the pitch.
    static func point(at fraction: Double, along points: [Point], on pitch: Pitch.Kind) -> Point {
        guard let first = points.first else { return .centre }
        guard points.count > 1 else { return first }

        let (length, width) = pitch.size
        let segments = zip(points, points.dropFirst()).map { a, b in
            hypot((b.x - a.x) * width, (b.y - a.y) * length)
        }
        let total = segments.reduce(0, +)
        guard total > 0 else { return first }

        var remaining = fraction.clamped(to: 0...1) * total
        for (index, segment) in segments.enumerated() {
            if remaining <= segment, segment > 0 {
                let a = points[index]
                let b = points[index + 1]
                let s = remaining / segment
                return Point(x: a.x + (b.x - a.x) * s, y: a.y + (b.y - a.y) * s)
            }
            remaining -= segment
        }
        return points[points.count - 1]
    }
}
