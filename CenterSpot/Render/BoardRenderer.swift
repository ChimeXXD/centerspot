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
        /// A library card (D-74): the pitch turned sideways, bigger discs, numbers only when legible.
        var card: CardStyle?
        /// Playback and export through the tilted broadcast camera (D-66, BR-2), looking at this point on the pitch
        /// (`CameraTrack`). Nil draws the flat board.
        var broadcast: Point?
        /// Reduce Motion's still broadcast view (D-76): fit this whole area instead of following `broadcast`.
        var broadcastSpan: CameraTrack.Span?
        /// Drawn above every other player without a ring: the one being dragged, so it never slides under another
        /// (D-93). Nil puts the selection on top.
        var onTop: String?

        init(selection: String? = nil, dimsUnselected: Bool = false, showsLift: Bool = false, fillsBackground: Bool = false,
             selectedMark: String? = nil, pendingLine: [String] = [], card: CardStyle? = nil, broadcast: Point? = nil,
             broadcastSpan: CameraTrack.Span? = nil) {
            self.selection = selection
            self.dimsUnselected = dimsUnselected
            self.showsLift = showsLift
            self.fillsBackground = fillsBackground
            self.selectedMark = selectedMark
            self.pendingLine = pendingLine
            self.card = card
            self.broadcast = broadcast
            self.broadcastSpan = broadcastSpan
        }
    }

    /// Opacity of the other tokens while one is dimmed against (the mockup's 0.35).
    static let dimmedOpacity: CGFloat = 0.35

    /// The pitch, then the marks on the grass (D-65), the arrows, then each token whole, body then number, back to front
    /// (D-93: a number under another disc is clipped by it, not hidden).
    /// A library card (`options.card`, D-74) turns the grass, marks and arrows a quarter clockwise; the discs are then
    /// drawn where the turn puts them, so numbers stay upright and the ball stays at its carrier's lower right.
    static func draw(state: BoardState, tactic: Tactic, in ctx: CGContext, rect: CGRect, options: Options = .init()) {
        if let camera = camera(for: options, in: rect, kind: tactic.pitch.kind) {
            drawBroadcast(state: state, tactic: tactic, in: ctx, rect: rect, camera: camera, options: options)
            return
        }
        let card = options.card
        let g = card?.geometry(kind: tactic.pitch.kind, in: rect) ?? BoardGeometry(kind: tactic.pitch.kind, fitting: rect)
        let turn = card?.sideways == true ? CardStyle.sidewaysTransform(into: rect) : .identity
        if options.fillsBackground {
            ctx.setFillColor(Tokens.Colour.bg.cgColor)
            ctx.fill(rect)
        }
        let centres = g.drawnCentres(positions: state.positions, tokens: tactic.tokens, carry: state.carry)
        // On a card the discs keep their on-screen offset (the ball down and to the right of its carrier), so what is
        // drawn under the turn (rings, lines, arrow ends) uses where those discs land, turned back.
        let discCentres = turn.isIdentity ? centres : turned(centres, positions: state.positions, geometry: g, by: turn)
        let sceneCentres = turn.isIdentity ? centres : discCentres.mapValues { $0.applying(turn.inverted()) }

        ctx.saveGState()
        ctx.concatenate(turn)
        PitchDrawing.draw(tactic.pitch, geometry: g, minimumLine: card?.minimumPitchLine ?? 0, in: ctx)
        let scene = MarkDrawing.Scene(tactic: tactic, geometry: g, centres: sceneCentres,
                                      minimumLine: card?.minimumMarkLine ?? 0)
        MarkDrawing.draw(state.marks, in: scene, selected: options.selectedMark, pendingLine: options.pendingLine, ctx: ctx)
        let tokenCentres = Array(sceneCentres.values)
        for visible in state.arrows {
            ArrowDrawing.draw(visible.arrow, opacity: CGFloat(visible.opacity), geometry: g, tokenCentres: tokenCentres,
                              minimumScale: card?.minimumArrowScale ?? 0, in: ctx)
        }
        ctx.restoreGState()

        // Each token whole, body then number, in drawing order (D-93): one on top of another lies over it like a coin,
        // with its dark outline between them; the number underneath stays, clipped where the top disc covers it.
        let numbers = card?.showsNumbers(radius: g.tokenRadius) ?? true
        let discs = drawingOrder(tactic.tokens, selected: options.onTop ?? options.selection).compactMap { token in
            discCentres[token.id].map { Disc(token, at: $0, kit: kit(for: token, in: tactic)) }
        }
        // The selection ring first, under every body, so it never crosses a neighbour's number.
        for disc in discs where disc.token.id == options.selection {
            TokenDrawing.drawSelection(disc.token, at: disc.centre, radius: g.tokenRadius, style: style(of: disc.token, options),
                                       in: ctx)
        }
        for disc in discs {
            let token = disc.token, c = disc.centre, kit = disc.kit
            var style = style(of: token, options)
            style.ringDrawn = true
            TokenDrawing.drawBody(token, at: c, kit: kit, radius: g.tokenRadius, style: style, in: ctx)
            guard numbers else { continue }
            TokenDrawing.drawNumber(token, at: c, kit: kit, radius: g.tokenRadius, style: style, in: ctx)
        }
    }

    /// Drawn centres moved by `turn`: each token's place on the pitch is turned, and any offset from it (the ball at
    /// its carrier's feet) is kept as it is on screen, down and to the right.
    private static func turned(_ centres: [String: CGPoint], positions: [String: Point], geometry g: BoardGeometry,
                               by turn: CGAffineTransform) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        for (id, c) in centres {
            guard let p = positions[id] else { continue }
            let place = g.point(p), spot = place.applying(turn)
            result[id] = CGPoint(x: spot.x + c.x - place.x, y: spot.y + c.y - place.y)
        }
        return result
    }

    static func style(of token: Token, _ options: Options) -> TokenDrawing.Style {
        let selected = options.selection == token.id
        var style = TokenDrawing.Style()
        style.selected = selected
        style.lift = selected && options.showsLift
        if options.dimsUnselected, !selected { style.opacity = dimmedOpacity }
        style.minimumOutline = options.card?.minimumOutline ?? 0
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

    /// Players and cones in board order, the selected one on top of them (D-93: tap a stacked player to bring them
    /// forward), the ball last so it is never hidden under its carrier.
    static func drawingOrder(_ tokens: [Token], selected: String? = nil) -> [Token] {
        let field = tokens.filter { $0.kind != .ball }
        return field.filter { $0.id != selected } + field.filter { $0.id == selected } + tokens.filter { $0.kind == .ball }
    }

    /// A token where it is drawn, with its kit worked out once.
    struct Disc {
        let token: Token
        let centre: CGPoint
        let kit: Tokens.Kit?

        init(_ token: Token, at centre: CGPoint, kit: Tokens.Kit?) {
            self.token = token
            self.centre = centre
            self.kit = kit
        }
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
