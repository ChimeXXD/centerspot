import Foundation

/// Turns a drawn stroke into the line an arrow stores (D-72): Straight joins its ends; Curved is one quadratic Bézier
/// bend fitted to it. Pure, and the result is ordinary path points, so the file format doesn't change.
///
/// Why quadratic: one bend has one control, which is exactly what the middle dot moves. A quadratic is always a single
/// convex arc that never loops or S-bends, and its point half way (t = ½) is its deepest from the chord, so the dot
/// sits on the line at the bend's apex: the control is `2·dot − (start + end)/2`. A cubic needs two controls, so one
/// dot would leave it under-determined, and it can S-bend, which "one smooth bend" rules out.
///
/// Distances are measured as the pitch looks (`aspect` is its length over its width); the curve itself is built in
/// pitch units, which gives the same curve because a Bézier is unchanged by stretching its controls.
enum ShapedPath {
    /// Points in a curved path: odd, so the middle sample is the dot; 24 segments turn a few degrees each, smooth at
    /// any board size, and far under the 200-point cap.
    static let curveSamples = 25
    /// A bend shallower than this share of the chord reads as a straight line drawn by a finger: about the sag of an
    /// arc that turns 37° in all. Finger strokes meant straight bow 3–6 %; a meant curve is well past 10 %.
    static let straightRatio = 0.08
    /// …or shallower than this, in pitch widths (about 3.5 pt on a 345 pt pitch): finger jitter on a short stroke.
    static let straightFloor = 0.01
    /// The dot stays between a quarter and three quarters of the way along the chord, so the line always moves toward
    /// its end (the control then projects inside the chord) and never hooks back past it.
    static let dotRange = 0.25...0.75

    /// The stored line for `stroke` (normalised points, start and end where the finger was). Every point is on the
    /// pitch. A stroke with no chord, or a curve shallower than the straight threshold, comes out as its two ends.
    static func path(for stroke: [Point], shape: ArrowShape, aspect: Double = 1) -> [Point] {
        guard let first = stroke.first?.clamped, let last = stroke.last?.clamped else { return [] }
        guard shape == .curved else { return [first, last] }
        let frame = Chord(first, last, aspect: aspect)
        guard frame.length > 0 else { return [first, last] }
        // The deepest point either side of the chord: its side and depth are the bend's.
        var deepest = (along: 0.5, off: 0.0)
        for point in stroke.dropFirst().dropLast() {
            let (along, off) = frame.coordinates(of: point.clamped)
            if abs(off) > abs(deepest.off) { deepest = (along, off) }
        }
        guard abs(deepest.off) >= max(straightFloor, straightRatio * frame.length) else { return [first, last] }
        return curve(frame, along: deepest.along, off: deepest.off)
    }

    /// Where the middle dot is drawn: the apex of one of our curves; for any other line with points between its ends
    /// (an older freehand arrow) the one furthest from the line joining its ends, where it bends most; otherwise the
    /// point half way along it (a straight arrow's midpoint). Nil for an empty path.
    static func middle(of path: [Point], aspect: Double = 1) -> Point? {
        guard let first = path.first, let last = path.last else { return nil }
        if isOwnCurve(path) { return path[curveSamples / 2] }
        let frame = Chord(first, last, aspect: aspect)
        if path.count > 2, frame.length > 0 {
            var furthest = (point: first, off: 0.0)
            for point in path.dropFirst().dropLast() {
                let off = abs(frame.coordinates(of: point).off)
                if off > furthest.off { furthest = (point, off) }
            }
            if furthest.off > 1e-9 { return furthest.point }  // not rounding error on a straight line
        }
        let lengths = zip(path, path.dropFirst()).map { hypot($1.x - $0.x, ($1.y - $0.y) * aspect) }
        var remaining = lengths.reduce(0, +) / 2
        for (i, length) in lengths.enumerated() where length > 0 {
            if remaining <= length {
                let a = path[i], b = path[i + 1], s = remaining / length
                return Point(x: a.x + (b.x - a.x) * s, y: a.y + (b.y - a.y) * s)
            }
            remaining -= length
        }
        return first
    }

    /// Whether `path` is one of our curves: `curveSamples` points, every one where the quadratic through its ends and
    /// its middle sample puts it. The test doesn't depend on the pitch's shape (a Bézier is unchanged by stretching).
    private static func isOwnCurve(_ path: [Point]) -> Bool {
        guard path.count == curveSamples, let a = path.first, let b = path.last else { return false }
        let rebuilt = quadratic(from: a, through: path[curveSamples / 2], to: b)
        return zip(rebuilt, path).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 }
    }

    /// Where VoiceOver's bend more (`delta` > 0) or less moves the middle dot: `delta` pitch widths further from the
    /// chord on the side it bends to. Less than straight is straight (on the chord), never a bend the other way.
    static func dot(of path: [Point], bentBy delta: Double, aspect: Double = 1) -> Point? {
        guard let first = path.first, let last = path.last, let dot = middle(of: path, aspect: aspect) else { return nil }
        let frame = Chord(first, last, aspect: aspect)
        guard frame.length > 0 else { return nil }
        let (along, off) = frame.coordinates(of: dot)
        let side: Double = off < 0 ? -1 : 1
        return frame.point(along: along, off: side * max(abs(off) + delta, 0)).clamped
    }

    /// `path` re-bent so its middle dot is at `dot` (pulled onto the pitch and between the quarters), keeping its ends.
    /// A dot dropped within `straightFloor` of the chord straightens it: a small detent, not the drawing threshold,
    /// so the line doesn't jump while the dot is dragged.
    static func nudged(_ path: [Point], dotTo dot: Point, aspect: Double = 1) -> [Point] {
        guard let first = path.first, let last = path.last else { return path }
        let frame = Chord(first, last, aspect: aspect)
        guard frame.length > 0 else { return [first, last] }
        let (along, off) = frame.coordinates(of: dot.clamped)
        guard abs(off) >= straightFloor else { return [first, last] }
        return curve(frame, along: along, off: off)
    }

    /// The quadratic from the chord's start to its end whose apex is `off` from the chord, `along` of the way along
    /// it, sampled evenly in t and clamped to the pitch.
    private static func curve(_ frame: Chord, along: Double, off: Double) -> [Point] {
        let dot = frame.point(along: along.clamped(to: dotRange), off: off).clamped
        return quadratic(from: frame.start, through: dot, to: frame.end)
    }

    /// `curveSamples` points, even in t, of the quadratic from `a` to `b` whose middle (t = ½) is `dot`.
    private static func quadratic(from a: Point, through dot: Point, to b: Point) -> [Point] {
        let control = Point(x: 2 * dot.x - (a.x + b.x) / 2, y: 2 * dot.y - (a.y + b.y) / 2)
        let last = curveSamples - 1
        return (0...last).map { i in
            if i == 0 { return a }
            if i == last { return b }
            if i == last / 2 { return dot }  // exactly the dot, so reading it back gives what was set
            let t = Double(i) / Double(last), u = 1 - t
            let x = u * u * a.x + 2 * u * t * control.x + t * t * b.x
            let y = u * u * a.y + 2 * u * t * control.y + t * t * b.y
            return Point(x: x, y: y).clamped
        }
    }
}

/// A start–end chord measured as the pitch looks: positions as (fraction along it, signed distance off it).
private struct Chord {
    let start: Point, end: Point, aspect: Double
    /// Its length in pitch widths, and its direction and left-hand normal in the stretched space (units).
    let length: Double
    private let dx: Double, dy: Double

    init(_ start: Point, _ end: Point, aspect: Double) {
        self.start = start
        self.end = end
        self.aspect = aspect
        let x = end.x - start.x, y = (end.y - start.y) * aspect
        length = hypot(x, y)
        (dx, dy) = length > 0 ? (x / length, y / length) : (0, 0)
    }

    func coordinates(of p: Point) -> (along: Double, off: Double) {
        let x = p.x - start.x, y = (p.y - start.y) * aspect
        return ((x * dx + y * dy) / length, x * -dy + y * dx)
    }

    func point(along: Double, off: Double) -> Point {
        let x = along * length * dx + off * -dy
        let y = along * length * dy + off * dx
        return Point(x: start.x + x, y: start.y + y / aspect)
    }
}
