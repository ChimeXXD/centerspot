import CoreGraphics
import Foundation

/// The broadcast pitch (D-65): near-black stripes, then thin light markings in full-pitch proportions on every kind, so
/// what VoiceOver calls "edge of the box" (`Placement`) is where the box is drawn (SPEC §4, §8).
enum PitchDrawing {
    /// Stripes across the pitch, top to bottom.
    static let stripeCount = 10
    /// Line width at the mockup's 345 pt pitch; never under 1.4 pt at phone size (UI-BRIEF §1).
    static let lineWidth: CGFloat = 1.4
    /// The pitch's corner radius at 345 pt.
    static let cornerRadius: CGFloat = 6

    /// - Parameters:
    ///   - minimumLine: the thinnest a marking may get (library cards keep 0.75 pt, D-74).
    ///   - camera: the broadcast camera (BR-2): `g` is then its plane, and the pitch is drawn through it.
    static func draw(_ pitch: Pitch, geometry g: BoardGeometry, minimumLine: CGFloat = 0, in ctx: CGContext,
                     camera: BroadcastCamera? = nil) {
        let rect = g.pitchRect
        let corner = cornerRadius * g.scale
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.clip(camera: camera)

        ctx.fill(rect, Tokens.Colour.bcPitchA.cgColor, camera: camera)
        if pitch.style == .stripes {
            let h = rect.height / CGFloat(stripeCount)
            for i in stride(from: 1, to: stripeCount, by: 2) {
                ctx.fill(CGRect(x: rect.minX, y: rect.minY + CGFloat(i) * h, width: rect.width, height: h),
                         Tokens.Colour.bcPitchB.cgColor, camera: camera)
            }
        }
        drawMarkings(geometry: g, width: max(lineWidth * g.scale, minimumLine), in: ctx, camera: camera)
        ctx.restoreGState()
    }

    private static func drawMarkings(geometry g: BoardGeometry, width w: CGFloat, in ctx: CGContext, camera: BroadcastCamera?) {
        let (sx, sy) = g.metreScale
        let chalk = Tokens.Colour.bcLine.cgColor
        let lines = CGMutablePath()

        lines.addRect(g.pitchRect.insetBy(dx: w / 2, dy: w / 2))
        lines.move(to: g.metres(0, 52.5))
        lines.addLine(to: g.metres(68, 52.5))
        lines.addEllipse(in: ellipse(centre: g.metres(34, 52.5), radius: 9.15, sx: sx, sy: sy))

        var spots = [g.metres(34, 52.5)]
        for top in [true, false] {
            // `edge` is the goal line, `d` points into the pitch.
            let edge: CGFloat = top ? 0 : 105, d: CGFloat = top ? 1 : -1
            lines.addRect(box(from: edge, depth: 16.5 * d, halfWidth: 20.16, geometry: g))
            lines.addRect(box(from: edge, depth: 5.5 * d, halfWidth: 9.16, geometry: g))
            let spot = g.metres(34, edge + 11 * d)
            spots.append(spot)
            // The arc outside the box: points 9.15 m from the spot, beyond the 16.5 m line.
            let half = acos(5.5 / 9.15)  // angle either side of the pitch's axis where the arc meets the box
            let towardCentre: CGFloat = top ? .pi / 2 : -.pi / 2
            let arc = CGMutablePath()
            let n = 24
            for i in 0...n {
                let a = towardCentre - half + 2 * half * CGFloat(i) / CGFloat(n)
                let p = CGPoint(x: spot.x + cos(a) * 9.15 * sx, y: spot.y + sin(a) * 9.15 * sy)
                if i == 0 { arc.move(to: p) } else { arc.addLine(to: p) }
            }
            lines.addPath(arc)
        }

        ctx.setLineWidth(w)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addPath(lines)
        ctx.strokePath(chalk, camera: camera)

        for spot in spots {
            let r = 1.4 * w
            ctx.fillEllipse(in: CGRect(x: spot.x - r, y: spot.y - r, width: 2 * r, height: 2 * r), chalk, camera: camera)
        }
    }

    private static func ellipse(centre c: CGPoint, radius: CGFloat, sx: CGFloat, sy: CGFloat) -> CGRect {
        CGRect(x: c.x - radius * sx, y: c.y - radius * sy, width: 2 * radius * sx, height: 2 * radius * sy)
    }

    private static func box(from edge: CGFloat, depth: CGFloat, halfWidth: CGFloat, geometry g: BoardGeometry) -> CGRect {
        let a = g.metres(34 - halfWidth, edge), b = g.metres(34 + halfWidth, edge + depth)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }
}
