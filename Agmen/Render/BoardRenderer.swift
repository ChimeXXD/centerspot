import CoreGraphics
import Foundation

/// The one board renderer (D-07). The screen calls it from `Canvas` through `withCGContext`; export and tests call
/// it on an offscreen bitmap through `image(...)`. Both hand it a y-down context, so the board is drawn one way only.
enum BoardRenderer {
    struct Options: Sendable, Equatable {
        /// The selected token gets a white chalk ring (UI-BRIEF §1).
        var selection: String?
        /// Fade every token but the selected one (behind the player sheet).
        var dimsUnselected = false
        /// A slight lift shadow under the selection; screen only (SPEC §4).
        var showsLift = false
        /// Fill the rect with the app background first (offscreen frames have no view behind them).
        var fillsBackground = false
        /// Draw mode (D-65): the selected mark (a zone shows its corner handles) and a shape line still being tapped
        /// out (its players so far, with a dashed ring round the last).
        var selectedMark: String?
        var pendingLine: [String] = []

        init(selection: String? = nil, dimsUnselected: Bool = false, showsLift: Bool = false, fillsBackground: Bool = false,
             selectedMark: String? = nil, pendingLine: [String] = []) {
            self.selection = selection
            self.dimsUnselected = dimsUnselected
            self.showsLift = showsLift
            self.fillsBackground = fillsBackground
            self.selectedMark = selectedMark
            self.pendingLine = pendingLine
        }
    }

    /// Opacity of the other tokens while one is dimmed against (the mockup's 0.35).
    static let dimmedOpacity: CGFloat = 0.35

    /// The pitch, then the marks on the grass (D-65), the arrows, every disc, and every number last (D-67).
    static func draw(state: BoardState, tactic: Tactic, in ctx: CGContext, rect: CGRect, options: Options = .init()) {
        let g = BoardGeometry(kind: tactic.pitch.kind, fitting: rect)
        if options.fillsBackground {
            ctx.setFillColor(Tokens.Colour.bg.cgColor)
            ctx.fill(rect)
        }
        PitchDrawing.draw(tactic.pitch, geometry: g, in: ctx)

        let centres = g.drawnCentres(positions: state.positions, tokens: tactic.tokens, carry: state.carry)
        MarkDrawing.draw(state.marks, in: .init(tactic: tactic, geometry: g, centres: centres),
                         selected: options.selectedMark, pendingLine: options.pendingLine, ctx: ctx)
        let tokenCentres = Array(centres.values)
        for visible in state.arrows {
            ArrowDrawing.draw(visible.arrow, opacity: CGFloat(visible.opacity), geometry: g, tokenCentres: tokenCentres, in: ctx)
        }

        // Kit and style worked out once per token; both passes use them.
        let tokens = drawingOrder(tactic.tokens).compactMap { token in
            centres[token.id].map { (token, $0, kit(for: token, in: tactic), style(of: token, options)) }
        }
        for (token, c, kit, style) in tokens {
            TokenDrawing.drawBody(token, at: c, kit: kit, radius: g.tokenRadius, style: style, in: ctx)
        }
        for (token, c, kit, style) in tokens {
            TokenDrawing.drawNumber(token, at: c, kit: kit, radius: g.tokenRadius, style: style, in: ctx)
        }
    }

    private static func style(of token: Token, _ options: Options) -> TokenDrawing.Style {
        let selected = options.selection == token.id
        var style = TokenDrawing.Style()
        style.selected = selected
        style.lift = selected && options.showsLift
        if options.dimsUnselected, !selected { style.opacity = dimmedOpacity }
        return style
    }

    /// `state`, with `next` laid over it at `mix` opacity: Reduce Motion's crossfade between resting steps (SPEC §8).
    /// The same drawing twice, composited, so a crossfade can't look different from either step.
    static func draw(state: BoardState, crossfadingTo next: BoardState?, mix: Double, tactic: Tactic, in ctx: CGContext,
                     rect: CGRect, options: Options = .init()) {
        draw(state: state, tactic: tactic, in: ctx, rect: rect, options: options)
        guard let next, mix > 0 else { return }
        ctx.saveGState()
        ctx.setAlpha(CGFloat(min(mix, 1)))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        draw(state: next, tactic: tactic, in: ctx, rect: rect, options: options)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    /// Players and cones in board order, the ball last so it is never hidden under its carrier.
    static func drawingOrder(_ tokens: [Token]) -> [Token] {
        tokens.filter { $0.kind != .ball } + tokens.filter { $0.kind == .ball }
    }

    static func kit(for token: Token, in tactic: Tactic) -> Tokens.Kit? {
        guard token.kind == .player, let side = token.side else { return nil }
        let colour = tactic.sides.first { $0.id == side }?.colour ?? Side.defaultColour(for: side)
        return Tokens.kit(colour)
    }

    /// The board drawn into a new sRGB bitmap of `size` points at `scale` pixels per point, y-down like the screen.
    static func image(state: BoardState, tactic: Tactic, size: CGSize, scale: CGFloat = 1, options: Options = .init()) -> CGImage? {
        let width = Int((size.width * scale).rounded()), height = Int((size.height * scale).rounded())
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: scale, y: -scale)
        var options = options
        options.fillsBackground = true
        draw(state: state, tactic: tactic, in: ctx, rect: CGRect(origin: .zero, size: size), options: options)
        return ctx.makeImage()
    }
}
