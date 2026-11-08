import CoreGraphics
import CoreText
import Foundation

/// Players, the ball and cones (SPEC §4, D-15): home filled discs with kit-ink numbers, away rings with a dark
/// centre and a white number, the ball a small white disc with a dark outline, the selection a white chalk ring.
/// D-67: every disc has a thin dark outline, and the board draws every body before any number (`drawBody`, then
/// `drawNumber`), so a disc that overlaps a neighbour never hides their number.
enum TokenDrawing {
    /// Shirt numbers: heavy Nunito (D-44), sized to the disc rather than Dynamic Type.
    static let numberWeight: CGFloat = 800
    /// D-67's outline, in disc radii: thin, just outside the disc's edge.
    static let outlineWidth: CGFloat = 0.1
    /// A number's point size, in disc radii.
    static let numberSizeRatio: CGFloat = 1.05

    struct Style: Sendable {
        var selected = false
        var opacity: CGFloat = 1
        /// The slight lift under a selected token, on screen only (SPEC §4).
        var lift = false
        /// The dark outline is at least this wide (library cards: 0.6 pt, D-74).
        var minimumOutline: CGFloat = 0
    }

    /// The whole token, body then number: for one token on its own (the lineup card's list).
    static func draw(_ token: Token, at c: CGPoint, kit: Tokens.Kit?, radius r: CGFloat, style: Style, in ctx: CGContext) {
        drawBody(token, at: c, kit: kit, radius: r, style: style, in: ctx)
        drawNumber(token, at: c, kit: kit, radius: r, style: style, in: ctx)
    }

    /// Everything but the number: the selection ring, the disc or ring with its outlines, the ball, a cone.
    static func drawBody(_ token: Token, at c: CGPoint, kit: Tokens.Kit?, radius r: CGFloat, style: Style, in ctx: CGContext) {
        faded(style.opacity, in: ctx) {
            switch token.kind {
            case .ball:
                if style.selected { selectionRing(at: c, radius: r * 0.42 + r * 0.6, width: r * 0.14, in: ctx) }
                disc(at: c, radius: r * 0.42, fill: Tokens.Colour.ball.cgColor, in: ctx)
                ring(at: c, radius: r * 0.42, width: max(r * 0.14, style.minimumOutline), colour: Tokens.Colour.bg.cgColor, in: ctx)
            case .cone, .marker:
                if style.selected { selectionRing(at: c, radius: r * 1.1, width: r * 0.14, in: ctx) }
                let h = r * 0.95
                let cone = CGMutablePath()
                cone.move(to: CGPoint(x: c.x, y: c.y - h * 0.75))
                cone.addLine(to: CGPoint(x: c.x + h * 0.6, y: c.y + h * 0.5))
                cone.addLine(to: CGPoint(x: c.x - h * 0.6, y: c.y + h * 0.5))
                cone.closeSubpath()
                ctx.addPath(cone)
                ctx.setFillColor(Tokens.Colour.dribble.cgColor)
                ctx.setStrokeColor(Tokens.Colour.bg.cgColor)
                ctx.setLineWidth(r * 0.12)
                ctx.setLineJoin(.round)
                ctx.drawPath(using: .fillStroke)
            case .player:
                player(token, at: c, kit: kit, radius: r, style: style, in: ctx)
            }
        }
    }

    /// A player's number, in their kit's ink (home) or white (away). Nothing for other tokens or a player without one.
    static func drawNumber(_ token: Token, at c: CGPoint, kit: Tokens.Kit?, radius r: CGFloat, style: Style, in ctx: CGContext) {
        guard token.kind == .player, let number = token.number else { return }
        let ink = token.side == .away ? Tokens.Colour.awayInk : (kit ?? Tokens.kit(.lime)).ink
        faded(style.opacity, in: ctx) { drawNumber(number, at: c, radius: r, colour: ink.cgColor, in: ctx) }
    }

    private static func player(_ token: Token, at c: CGPoint, kit: Tokens.Kit?, radius r: CGFloat, style: Style, in ctx: CGContext) {
        let kit = kit ?? Tokens.kit(token.side == .away ? .coral : .lime)
        if style.selected {
            if style.lift {
                ctx.setShadow(offset: CGSize(width: 0, height: r * 0.25), blur: r * 0.6, color: RGBA(0x000000, alpha: 0.5).cgColor)
            }
            selectionRing(at: c, radius: r * 1.45, width: r * 0.14, in: ctx)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
        // The outermost edge so far, for D-67's dark outline just beyond it.
        var edge: CGFloat
        if token.side == .away {
            disc(at: c, radius: r * 0.9, fill: Tokens.Colour.awayInner.cgColor, in: ctx)
            ring(at: c, radius: r * 0.9, width: r * 0.24, colour: kit.fill.cgColor, in: ctx)
            edge = r * 1.02
            if let outline = kit.outline {
                ring(at: c, radius: r * 1.06, width: r * 0.08, colour: outline.cgColor, in: ctx)
                edge = r * 1.1
            }
        } else {
            disc(at: c, radius: r, fill: kit.fill.cgColor, in: ctx)
            if let outline = kit.outline { ring(at: c, radius: r - r * 0.05, width: r * 0.1, colour: outline.cgColor, in: ctx) }
            edge = r
        }
        let width = max(r * outlineWidth, style.minimumOutline)
        ring(at: c, radius: edge + width / 2, width: width, colour: Tokens.Colour.discOutline.cgColor, in: ctx)
    }

    /// Runs `draw` at `opacity` as one layer, so overlapping parts of the token don't show through each other.
    private static func faded(_ opacity: CGFloat, in ctx: CGContext, _ draw: () -> Void) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if opacity < 1 {
            ctx.setAlpha(opacity)
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        draw()
        if opacity < 1 { ctx.endTransparencyLayer() }
    }

    private static func disc(at c: CGPoint, radius r: CGFloat, fill: CGColor, in ctx: CGContext) {
        ctx.setFillColor(fill)
        ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    private static func ring(at c: CGPoint, radius r: CGFloat, width: CGFloat, colour: CGColor, in ctx: CGContext) {
        ctx.setStrokeColor(colour)
        ctx.setLineWidth(width)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// White chalk, so it shows on every kit, including the lime home side (UI-BRIEF §1).
    private static func selectionRing(at c: CGPoint, radius: CGFloat, width: CGFloat, in ctx: CGContext) {
        ring(at: c, radius: radius, width: width, colour: Tokens.Colour.text.cgColor, in: ctx)
    }

    /// Centred on the disc, baseline at `y + 0.36 r` as in the mockup. Expects a y-down context.
    private static func drawNumber(_ number: Int, at c: CGPoint, radius r: CGFloat, colour: CGColor, in ctx: CGContext) {
        let font = numberFont(size: r * numberSizeRatio)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "\(number)", attributes: attributes))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        ctx.textPosition = CGPoint(x: c.x - CGFloat(width) / 2, y: c.y + r * 0.36)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Heavy Nunito from the bundled variable font (weight axis 800), falling back to the system's heavy rounded face.
    static func numberFont(size: CGFloat) -> CTFont {
        let wght = 0x7767_6874  // 'wght'
        let descriptor = CTFontDescriptorCreateWithAttributes([
            kCTFontNameAttribute: Tokens.Typeface.uiName,
            kCTFontVariationAttribute: [wght: numberWeight],
        ] as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        if (CTFontCopyFamilyName(font) as String).hasPrefix(Tokens.Typeface.uiName) { return font }
        return CTFontCreateUIFontForLanguage(.system, size, nil) ?? font
    }
}
