import CoreGraphics
import Foundation

/// Arrows by line style, not only colour (D-15): run solid with a head, pass dashed with a head, dribble a zigzag
/// with a head, press a short double chevron. An arrow that ends on a token stops short of the disc so its head
/// stays visible. Sizes follow the mockup at a 345 pt pitch and scale with it.
enum ArrowDrawing {
    static let lineWidth: CGFloat = 2.6
    static let headLength: CGFloat = 9
    static let headAngle: CGFloat = 0.45
    static let passDash: [CGFloat] = [7, 5]
    static let zigzagStep: CGFloat = 9
    static let zigzagAmplitude: CGFloat = 3.5

    static func colour(for kind: Arrow.Kind) -> RGBA {
        switch kind {
        case .run: Tokens.Colour.run
        case .pass: Tokens.Colour.pass
        case .dribble: Tokens.Colour.dribble
        case .press: Tokens.Colour.press
        }
    }

    /// - Parameters:
    ///   - tokenCentres: where tokens are drawn, so the arrow can stop short of one at its end.
    ///   - minimumScale: the smallest scale its sizes may take (library cards keep 0.55, D-74).
    ///   - camera: the broadcast camera (BR-2): `g` is then its plane, and the arrow lies on the grass.
    static func draw(_ arrow: Arrow, opacity: CGFloat, geometry g: BoardGeometry, tokenCentres: [CGPoint],
                     minimumScale: CGFloat = 0, in ctx: CGContext, camera: BroadcastCamera? = nil) {
        var points = arrow.points.map(g.point)
        guard points.count >= 2, opacity > 0 else { return }
        let k = max(g.scale, minimumScale), r = g.tokenRadius
        shortenEnd(&points, radius: r, tokenCentres: tokenCentres)
        let end = points[points.count - 1]
        // The head points along the last stretch that goes somewhere: a clamped curve can end in repeated points.
        let before = points.dropLast().last { hypot(end.x - $0.x, end.y - $0.y) > 0.5 } ?? points[points.count - 2]
        let angle = atan2(end.y - before.y, end.x - before.x)

        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setAlpha(opacity)
        let ink = colour(for: arrow.kind).cgColor
        ctx.setLineWidth(lineWidth * k)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch arrow.kind {
        case .press:
            // Two chevrons pointing where the press goes, ending at the arrow's end.
            let gap = 6 * k
            for i in 0..<2 {
                let tip = CGPoint(x: end.x - cos(angle) * gap * CGFloat(i), y: end.y - sin(angle) * gap * CGFloat(i))
                ctx.addPath(head(at: tip, angle: angle, length: 8 * k, spread: 0.75))
            }
            ctx.strokePath(ink, camera: camera)
            return
        case .dribble:
            ctx.addPath(zigzag(points, scale: k))
        case .run, .pass:
            let line = CGMutablePath()
            line.addLines(between: points)
            ctx.addPath(line)
        }
        ctx.saveGState()
        if arrow.kind == .pass { ctx.setLineDash(phase: 0, lengths: passDash.map { $0 * k }) }
        ctx.strokePath(ink, camera: camera)
        ctx.restoreGState()
        ctx.addPath(head(at: end, angle: angle, length: headLength * k, spread: headAngle))
        ctx.strokePath(ink, camera: camera)
    }

    /// If any token is drawn within 1.2 radii of the end, pull the end back along the line by up to 1.35 radii.
    private static func shortenEnd(_ points: inout [CGPoint], radius r: CGFloat, tokenCentres: [CGPoint]) {
        let last = points[points.count - 1]
        guard tokenCentres.contains(where: { hypot($0.x - last.x, $0.y - last.y) < r * 1.2 }) else { return }
        points = trimmedEnd(points, by: r * 1.35)
    }

    /// `points` with `cut` taken off the end by arc length (never more than half the line), so a finely sampled
    /// curve (D-72) still stops short of a disc and not just its last tiny segment.
    static func trimmedEnd(_ points: [CGPoint], by cut: CGFloat) -> [CGPoint] {
        let lengths = zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var remaining = min(cut, lengths.reduce(0, +) / 2)
        var result = points
        while remaining > 0, result.count >= 2 {
            let b = result[result.count - 1], a = result[result.count - 2]
            let length = hypot(b.x - a.x, b.y - a.y)
            if length > remaining {
                result[result.count - 1] = CGPoint(x: b.x - (b.x - a.x) / length * remaining,
                                                   y: b.y - (b.y - a.y) / length * remaining)
                return result
            }
            result.removeLast()
            remaining -= length
        }
        return result
    }

    private static func head(at tip: CGPoint, angle: CGFloat, length h: CGFloat, spread: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tip.x - h * cos(angle - spread), y: tip.y - h * sin(angle - spread)))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - h * cos(angle + spread), y: tip.y - h * sin(angle + spread)))
        return path
    }

    /// A zigzag along the whole line, flat at the end so the head sits on it. Its teeth are spaced by arc length, not
    /// per segment, so a curve sampled in short segments (D-72) still waves to both sides; on a two-point line it is
    /// the same zigzag as before.
    static func zigzag(_ points: [CGPoint], scale k: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        let lengths = zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        let total = lengths.reduce(0, +)
        guard total > 0 else { return path }
        let n = max(2, Int((total / (zigzagStep * k)).rounded()))
        var segment = 0, start: CGFloat = 0  // the segment the next tooth falls on, and the arc length where it starts
        for j in 1...n {
            let at = total * CGFloat(j) / CGFloat(n)
            while segment < lengths.count - 1, start + lengths[segment] < at || lengths[segment] == 0 {
                start += lengths[segment]
                segment += 1
            }
            let a = points[segment], b = points[segment + 1], length = lengths[segment]
            let t = length > 0 ? min(1, (at - start) / length) : 1
            let nx = length > 0 ? -(b.y - a.y) / length : 0, ny = length > 0 ? (b.x - a.x) / length : 0
            let amp = j == n ? 0 : (j % 2 == 1 ? zigzagAmplitude : -zigzagAmplitude) * k
            path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t + nx * amp, y: a.y + (b.y - a.y) * t + ny * amp))
        }
        return path
    }
}
