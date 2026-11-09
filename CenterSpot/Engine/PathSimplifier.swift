import Foundation

/// Turns a drawn stroke into a run or arrow the file can hold (D-08): Douglas–Peucker, then capped at 200 points.
/// The first and last points are always kept, and a result has at least two points unless the stroke had none.
///
/// It runs on the main thread when a stroke ends, so its cost is bounded whatever the stroke: near-duplicate samples
/// are dropped first (a slow Pencil sends many), at most `maxInputPoints` go into Douglas–Peucker, and Douglas–Peucker
/// runs once, ranking every point, so the cap never re-runs it.
enum PathSimplifier {
    /// A path holds at most 200 points (docs/FORMAT.md).
    static let maxPoints = Path.pointCountRange.upperBound
    /// Points closer than this to the simplified line are dropped, in pitch widths (about 1.4 pt on a 345 pt pitch).
    static let tolerance = 0.004
    /// Douglas–Peucker is quadratic at worst; longer strokes are evenly thinned to this many points first.
    static let maxInputPoints = 1_000

    /// - Parameter aspect: the pitch's length over its width, so distance up the pitch counts as it looks on screen.
    static func simplify(_ points: [Point], aspect: Double = 1, maxPoints: Int = maxPoints) -> [Point] {
        guard let first = points.first, let last = points.last else { return [] }
        var input = thinned(points, spacing: tolerance / 2, aspect: aspect)
        if input.count > maxInputPoints { input = evenly(input, count: maxInputPoints) }
        guard input.count > 2 else { return [first, last] }

        let ranks = significance(input, aspect: aspect)
        var kept = input.indices.dropFirst().dropLast().filter { ranks[$0].distance > tolerance }
        let cap = max(maxPoints, 2) - 2
        if kept.count > cap {
            // The most significant points; ties go to the one split first, so a point never stays without the
            // point that made it worth keeping.
            kept = kept.sorted { (ranks[$0].distance, -ranks[$0].order) > (ranks[$1].distance, -ranks[$1].order) }
            kept = Array(kept.prefix(cap)).sorted()
        }
        return [first] + kept.map { input[$0] } + [last]
    }

    /// Each interior point's Douglas–Peucker significance: the smallest split distance on its way down the recursion
    /// (it is kept at a tolerance exactly when this is above it), and the order it was split in. Iterative, so a long
    /// stroke can't overflow the stack.
    private static func significance(_ points: [Point], aspect: Double) -> [(distance: Double, order: Int)] {
        var ranks = [(distance: Double, order: Int)](repeating: (0, .max), count: points.count)
        var order = 0
        var ranges = [(start: 0, end: points.count - 1, limit: Double.infinity)]
        while let (start, end, limit) = ranges.popLast() {
            guard end > start + 1 else { continue }
            var farthest = (index: start, distance: 0.0)
            for i in (start + 1)..<end {
                let d = distance(points[i], toSegment: points[start], points[end], aspect: aspect)
                if d > farthest.distance { farthest = (i, d) }
            }
            guard farthest.distance > 0 else { continue }  // all on the line: none is significant
            let rank = min(farthest.distance, limit)
            ranks[farthest.index] = (rank, order)
            order += 1
            ranges.append((start, farthest.index, rank))
            ranges.append((farthest.index, end, rank))
        }
        return ranks
    }

    /// Drops samples within `spacing` of the last one kept; the first and last points always stay.
    private static func thinned(_ points: [Point], spacing: Double, aspect: Double) -> [Point] {
        guard points.count > 2 else { return points }
        var kept = [points[0]]
        for p in points.dropFirst().dropLast() {
            let q = kept[kept.count - 1]
            if hypot(p.x - q.x, (p.y - q.y) * aspect) >= spacing { kept.append(p) }
        }
        kept.append(points[points.count - 1])
        return kept
    }

    /// `count` points spread evenly through `points` by index, the ends included.
    private static func evenly(_ points: [Point], count: Int) -> [Point] {
        (0..<count).map { points[Int((Double($0) * Double(points.count - 1) / Double(count - 1)).rounded())] }
    }

    /// Distance from `p` to the segment `a`–`b` in pitch widths; a zero-length segment is its point.
    private static func distance(_ p: Point, toSegment a: Point, _ b: Point, aspect: Double) -> Double {
        let (px, py) = (p.x - a.x, (p.y - a.y) * aspect)
        let (dx, dy) = (b.x - a.x, (b.y - a.y) * aspect)
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return hypot(px, py) }
        let s = ((px * dx + py * dy) / lengthSquared).clamped(to: 0...1)
        return hypot(px - s * dx, py - s * dy)
    }
}
