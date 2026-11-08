import CoreGraphics
import Foundation

/// Zones, shape lines, glow rings and heat (D-65), drawn on the grass under the arrows and discs in the mockup's order:
/// zones, heat, lines, rings. Lines and rings take their players' drawn centres, so they follow them through a move.
/// Sizes follow the mockup at a 345 pt pitch and scale with it; everything is clipped to the pitch, as in the mockup.
enum MarkDrawing {
    static let zoneLineWidth: CGFloat = 1.4
    static let lineWidth: CGFloat = 2.2
    static let lineOpacity: CGFloat = 0.9
    static let ringWidth: CGFloat = 1.6
    /// The three rings under a player: radius in disc radii and opacity, innermost first. The tint fills the first.
    static let rings: [(radius: CGFloat, opacity: CGFloat)] = [(1.3, 0.95), (1.85, 0.6), (2.45, 0.3)]
    /// Heat is an ellipse this much shorter than wide, like a glow seen on the grass (taps use the same, `MarkHit`).
    static let heatSquash = CGFloat(MarkHit.heatSquash)
    /// A selected zone's corner handles (draw mode only).
    static let handleRadius: CGFloat = 6
    static let handleStroke: CGFloat = 2
    /// The line being tapped out: a dashed ring this many disc radii round the last player tapped.
    static let pendingRingRadius: CGFloat = 1.75
    static let pendingDash: CGFloat = 3

    struct Scene {
        let tactic: Tactic
        let geometry: BoardGeometry
        /// Where each token is drawn (`BoardGeometry.drawnCentres`).
        let centres: [String: CGPoint]
        /// The thinnest a mark's line may get (library cards keep 1.2 pt, D-74).
        var minimumLine: CGFloat = 0
        /// The broadcast camera (BR-2): `geometry` is then its plane, and every mark lies on the grass through it.
        var camera: BroadcastCamera?

        /// A line `width` points wide at the 345 pt pitch, scaled to this one.
        func width(_ width: CGFloat) -> CGFloat { max(width * geometry.scale, minimumLine) }
    }

    static func draw(_ marks: [BoardState.VisibleMark], in scene: Scene, selected: String?, pendingLine: [String],
                     ctx: CGContext) {
        guard !marks.isEmpty || !pendingLine.isEmpty else { return }
        let g = scene.geometry, corner = PitchDrawing.cornerRadius * g.scale
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.addPath(CGPath(roundedRect: g.pitchRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
        ctx.clip(camera: scene.camera)

        for mark in marks { if case .zone(let zone) = mark.shape { draw(zone, opacity: mark.opacity, scene: scene, ctx: ctx) } }
        for mark in marks {
            if case .glow(let glow) = mark.shape, case let .spot(centre, radius) = glow.target {
                heat(at: centre, radius: radius, opacity: mark.opacity, g: g, camera: scene.camera, ctx: ctx)
            }
        }
        for mark in marks { if case .line(let line) = mark.shape { draw(line.tokens, opacity: mark.opacity, scene: scene, ctx: ctx) } }
        for mark in marks {
            if case .glow(let glow) = mark.shape, case .token(let id) = glow.target {
                rings(under: id, opacity: mark.opacity, scene: scene, ctx: ctx)
            }
        }
        // Draw mode only: the editor never looks through the camera.
        guard scene.camera == nil else { return }
        if !pendingLine.isEmpty { pending(pendingLine, scene: scene, ctx: ctx) }
        for mark in marks where mark.id == selected {
            if case .zone(let zone) = mark.shape { handles(zone, g: g, ctx: ctx) }
        }
    }

    /// The kit fill of a player's side, or nil for anything else.
    static func kitColour(of id: String, in tactic: Tactic) -> RGBA? {
        guard let token = tactic.tokens.first(where: { $0.id == id }) else { return nil }
        return BoardRenderer.kit(for: token, in: tactic)?.fill
    }

    /// A zone's box on screen: `x`, `y` is its bottom-left corner on the pitch (y up), so it is the rect's bottom left.
    static func rect(of zone: Zone, g: BoardGeometry) -> CGRect {
        let a = g.point(Point(x: zone.x, y: zone.y + zone.h)), b = g.point(Point(x: zone.x + zone.w, y: zone.y))
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }

    private static func draw(_ zone: Zone, opacity: Double, scene: Scene, ctx: CGContext) {
        let kit = Tokens.kit(zone.colour).fill, box = rect(of: zone, g: scene.geometry)
        ctx.saveGState()
        ctx.setAlpha(CGFloat(opacity))
        ctx.fill(box, kit.opacity(Tokens.Colour.zoneFill.alpha).cgColor, camera: scene.camera)
        ctx.setLineWidth(scene.width(zoneLineWidth))
        ctx.stroke(box, kit.opacity(Tokens.Colour.zoneStroke.alpha).cgColor, camera: scene.camera)
        ctx.restoreGState()
    }

    /// Through the camera the glow is drawn in the projection's shape at its centre (a soft glow; close enough).
    private static func heat(at centre: Point, radius: Double, opacity: Double, g: BoardGeometry, camera: BroadcastCamera?,
                             ctx: CGContext) {
        let stops: [(RGBA, Double, CGFloat)] = [(Tokens.Colour.heatCore, 0.7, 0), (Tokens.Colour.heat, 0.55, 0.35), (Tokens.Colour.heat, 0, 1)]
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let gradient = CGGradient(colorsSpace: space, colors: stops.map { $0.0.opacity($0.1).cgColor } as CFArray,
                                        locations: stops.map(\.2))
        else { return }
        let c = g.point(centre), rx = CGFloat(radius) * g.pitchRect.width
        ctx.saveGState()
        ctx.setAlpha(CGFloat(opacity))
        if let camera { ctx.concatenate(camera.local(at: c)) }
        ctx.translateBy(x: c.x, y: c.y)
        ctx.scaleBy(x: 1, y: heatSquash)
        ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: rx, options: [])
        ctx.restoreGState()
    }

    private static func draw(_ tokens: [String], opacity: Double, scene: Scene, ctx: CGContext) {
        let corners = tokens.compactMap { scene.centres[$0] }
        guard corners.count >= ShapeLine.minTokens, let first = tokens.first, let kit = kitColour(of: first, in: scene.tactic) else { return }
        ctx.saveGState()
        ctx.setAlpha(CGFloat(opacity) * lineOpacity)
        ctx.setLineWidth(scene.width(lineWidth))
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.addLines(between: corners)
        ctx.strokePath(kit.cgColor, camera: scene.camera)
        ctx.restoreGState()
    }

    private static func rings(under id: String, opacity: Double, scene: Scene, ctx: CGContext) {
        guard let c = scene.centres[id], let kit = kitColour(of: id, in: scene.tactic) else { return }
        let r = scene.geometry.tokenRadius
        ctx.saveGState()
        ctx.setAlpha(CGFloat(opacity))
        let tint = r * rings[0].radius
        ctx.fillEllipse(in: CGRect(x: c.x - tint, y: c.y - tint, width: 2 * tint, height: 2 * tint),
                        kit.opacity(Tokens.Colour.glowFillOpacity).cgColor, camera: scene.camera)
        ctx.setLineWidth(scene.width(ringWidth))
        for ring in rings {
            let rr = r * ring.radius
            ctx.strokeEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr),
                              kit.opacity(Double(ring.opacity)).cgColor, camera: scene.camera)
        }
        ctx.restoreGState()
    }

    /// The line so far, and a dashed ring round the last player tapped (mockup draw--tools-line).
    private static func pending(_ tokens: [String], scene: Scene, ctx: CGContext) {
        if tokens.count >= ShapeLine.minTokens { draw(tokens, opacity: 1, scene: scene, ctx: ctx) }
        guard let last = tokens.last, let c = scene.centres[last], let first = tokens.first,
              let kit = kitColour(of: first, in: scene.tactic) else { return }
        let k = scene.geometry.scale, rr = scene.geometry.tokenRadius * pendingRingRadius
        ctx.saveGState()
        ctx.setStrokeColor(kit.cgColor)
        ctx.setLineWidth(ringWidth * k)
        ctx.setLineDash(phase: 0, lengths: [pendingDash * k, pendingDash * k])
        ctx.strokeEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr))
        ctx.restoreGState()
    }

    /// White handles with a dark edge at the four corners of the selected zone (mockup draw--tools).
    private static func handles(_ zone: Zone, g: BoardGeometry, ctx: CGContext) {
        let box = rect(of: zone, g: g)
        handles(at: [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                     CGPoint(x: box.minX, y: box.maxY), CGPoint(x: box.maxX, y: box.maxY)], scale: g.scale, ctx: ctx)
    }

    /// The draw handle: a white dot with a dark edge, at each point (zone corners; an arrow's bend, D-72).
    static func handles(at points: [CGPoint], scale k: CGFloat, ctx: CGContext) {
        let r = handleRadius * k
        ctx.saveGState()
        ctx.setFillColor(Tokens.Colour.text.cgColor)
        ctx.setStrokeColor(Tokens.Colour.bg.cgColor)
        ctx.setLineWidth(handleStroke * k)
        for p in points {
            ctx.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        }
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
    }
}
