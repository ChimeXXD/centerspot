import CoreGraphics
import Foundation

/// D-40, exports only: a spotlit player's fading trail (where they've just been, `SpotlightTrail`) and a ring around
/// them. `BoardRenderer` draws the trail under the tokens and the ring over them, and dims everyone else slightly.
enum SpotlightDrawing {
    /// The trail's opacity at its newest end; it fades to nothing at the oldest.
    static let trailOpacity: CGFloat = 0.7

    /// Segment by segment, oldest first, each a little wider and more opaque than the last. Round caps hide the joins;
    /// inside one layer each segment replaces what it overlaps (`.copy`), so the caps don't stack into beads.
    static func trail(_ points: [Point], geometry g: BoardGeometry, in ctx: CGContext) {
        guard points.count > 1 else { return }
        let r = g.tokenRadius, centres = points.map(g.point)
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setBlendMode(.copy)
        ctx.setLineCap(.round)
        for i in 1..<centres.count {
            let share = CGFloat(i) / CGFloat(centres.count - 1)
            ctx.setStrokeColor(Tokens.Colour.text.cgColor.copy(alpha: trailOpacity * share) ?? Tokens.Colour.text.cgColor)
            ctx.setLineWidth(r * (0.25 + 0.65 * share))
            ctx.strokeLineSegments(between: [centres[i - 1], centres[i]])
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    /// A thick white chalk ring, wider than the selection ring so it reads at video size.
    static func ring(at c: CGPoint, radius r: CGFloat, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(Tokens.Colour.text.cgColor)
        ctx.setLineWidth(r * 0.22)
        let rr = r * 1.5
        ctx.strokeEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr))
        ctx.restoreGState()
    }
}
