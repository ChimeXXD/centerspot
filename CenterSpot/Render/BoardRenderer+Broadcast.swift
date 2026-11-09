import CoreGraphics
import Foundation

/// The board through the tilted broadcast camera (D-65, D-66, D-67, BR-2), for playback and export. Everything on the
/// grass (pitch, marks, arrows) is drawn on the camera's plane and projected; each disc lies flat in the projection's
/// shape where it stands, far to near so nearer discs cover farther ones, each with its number upright on it, sized to
/// its disc's distance (D-93: a nearer disc clips a farther one's number). One renderer still (D-07): the screen and the video both come through here.
extension BoardRenderer {
    /// The camera `options` ask for in `rect`, or nil for the flat board (and library cards).
    static func camera(for options: Options, in rect: CGRect, kind: Pitch.Kind) -> BroadcastCamera? {
        guard options.card == nil, let target = options.broadcast else { return nil }
        if let span = options.broadcastSpan { return BroadcastCamera(view: rect, kind: kind, framing: span) }
        return BroadcastCamera(view: rect, kind: kind, target: target)
    }

    static func drawBroadcast(state: BoardState, tactic: Tactic, in ctx: CGContext, rect: CGRect, camera: BroadcastCamera,
                              options: Options) {
        let g = camera.plane
        if options.fillsBackground {
            ctx.setFillColor(Tokens.Colour.bg.cgColor)
            ctx.fill(rect)
        }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.clip(to: rect)

        let centres = g.drawnCentres(positions: state.positions, tokens: tactic.tokens, carry: state.carry)
        PitchDrawing.draw(tactic.pitch, geometry: g, in: ctx, camera: camera)
        let scene = MarkDrawing.Scene(tactic: tactic, geometry: g, centres: centres, camera: camera)
        MarkDrawing.draw(state.marks, in: scene, selected: nil, pendingLine: [], ctx: ctx)
        let tokenCentres = Array(centres.values)
        for visible in state.arrows {
            ArrowDrawing.draw(visible.arrow, opacity: CGFloat(visible.opacity), geometry: g, tokenCentres: tokenCentres,
                              in: ctx, camera: camera)
        }

        // Far to near, each token whole (D-93): a nearer player lies over a farther one, number clipped, not hidden.
        let discs = farToNear(tactic.tokens, centres: centres).compactMap { token in
            centres[token.id].map { Disc(token, at: $0, kit: kit(for: token, in: tactic)) }
        }
        for disc in discs {
            let token = disc.token, c = disc.centre, kit = disc.kit, style = style(of: token, options)
            var flat = style
            flat.grass = camera
            TokenDrawing.drawBody(token, at: c, kit: kit, radius: g.tokenRadius, style: flat, in: ctx)
            TokenDrawing.drawNumber(token, at: camera.project(c), kit: kit, radius: g.tokenRadius * camera.depthScale(at: c),
                                    style: style, in: ctx)
        }
    }

    /// Players and cones from the far end to the near one (board order where they are level), the ball last as on the
    /// flat board, so it is never hidden under its carrier.
    static func farToNear(_ tokens: [Token], centres: [String: CGPoint]) -> [Token] {
        let order = Dictionary(uniqueKeysWithValues: tokens.enumerated().map { ($0.element.id, $0.offset) })
        func depth(_ token: Token) -> CGFloat { centres[token.id]?.y ?? 0 }
        let field = tokens.filter { $0.kind != .ball }.sorted {
            depth($0) != depth($1) ? depth($0) < depth($1) : order[$0.id, default: 0] < order[$1.id, default: 0]
        }
        return field + tokens.filter { $0.kind == .ball }
    }
}
