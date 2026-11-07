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

    /// - Parameter tokenCentres: where tokens are drawn, so the arrow can stop short of one at its end.
    static func draw(_ arrow: Arrow, opacity: CGFloat, geometry g: BoardGeometry, tokenCentres: [CGPoint], in ctx: CGContext) {
        var points = arrow.points.map(g.point)
        guard points.count >= 2, opacity > 0 else { return }
        let k = g.scale, r = g.tokenRadius
        shortenEnd(&points, radius: r, tokenCentres: tokenCentres)
        let end = points[points.count - 1], before = points[points.count - 2]
        let angle = atan2(end.y - before.y, end.x - before.x)

        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setAlpha(opacity)
        ctx.setStrokeColor(colour(for: arrow.kind).cgColor)
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
            ctx.strokePath()
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
        ctx.strokePath()
        ctx.restoreGState()
        ctx.addPath(head(at: end, angle: angle, length: headLength * k, spread: headAngle))
        ctx.strokePath()
    }

    /// If any token is drawn within 1.2 radii of the end, pull the end back along the last segment by up to 1.35 radii.
    private static func shortenEnd(_ points: inout [CGPoint], radius r: CGFloat, tokenCentres: [CGPoint]) {
        let last = points[points.count - 1], prev = points[points.count - 2]
        guard tokenCentres.contains(where: { hypot($0.x - last.x, $0.y - last.y) < r * 1.2 }) else { return }
        let length = hypot(last.x - prev.x, last.y - prev.y)
        guard length > 0 else { return }
        let cut = min(r * 1.35, length / 2)
        points[points.count - 1] = CGPoint(x: last.x - (last.x - prev.x) / length * cut,
                                           y: last.y - (last.y - prev.y) / length * cut)
    }

    private static func head(at tip: CGPoint, angle: CGFloat, length h: CGFloat, spread: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: tip.x - h * cos(angle - spread), y: tip.y - h * sin(angle - spread)))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - h * cos(angle + spread), y: tip.y - h * sin(angle + spread)))
        return path
    }

    /// A zigzag about each segment, flat at the end so the head sits on the line.
    static func zigzag(_ points: [CGPoint], scale k: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: points[0])
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            let n = max(2, Int((length / (zigzagStep * k)).rounded()))
            let nx = -(b.y - a.y) / length, ny = (b.x - a.x) / length
            for j in 1...n {
                let t = CGFloat(j) / CGFloat(n)
                let amp = j == n ? 0 : (j % 2 == 1 ? zigzagAmplitude : -zigzagAmplitude) * k
                path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t + nx * amp, y: a.y + (b.y - a.y) * t + ny * amp))
            }
        }
        return path
    }
}
