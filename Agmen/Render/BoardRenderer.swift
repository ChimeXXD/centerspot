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

        init(selection: String? = nil, dimsUnselected: Bool = false, showsLift: Bool = false, fillsBackground: Bool = false) {
            self.selection = selection
            self.dimsUnselected = dimsUnselected
            self.showsLift = showsLift
            self.fillsBackground = fillsBackground
        }
    }

    /// Opacity of the other tokens while one is dimmed against (the mockup's 0.35).
    static let dimmedOpacity: CGFloat = 0.35

    static func draw(state: BoardState, tactic: Tactic, in ctx: CGContext, rect: CGRect, options: Options = .init()) {
        let g = BoardGeometry(kind: tactic.pitch.kind, fitting: rect)
        if options.fillsBackground {
            ctx.setFillColor(Tokens.Colour.bg.cgColor)
            ctx.fill(rect)
        }
        PitchDrawing.draw(tactic.pitch, geometry: g, in: ctx)

        let centres = g.drawnCentres(positions: state.positions, tokens: tactic.tokens)
        let tokenCentres = Array(centres.values)
        for visible in state.arrows {
            ArrowDrawing.draw(visible.arrow, opacity: CGFloat(visible.opacity), geometry: g, tokenCentres: tokenCentres, in: ctx)
        }

        for token in drawingOrder(tactic.tokens) {
            guard let c = centres[token.id] else { continue }
            let selected = options.selection == token.id
            var style = TokenDrawing.Style()
            style.selected = selected
            style.lift = selected && options.showsLift
            if options.dimsUnselected, !selected { style.opacity = dimmedOpacity }
            TokenDrawing.draw(token, at: c, kit: kit(for: token, in: tactic), radius: g.tokenRadius, style: style, in: ctx)
        }
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
