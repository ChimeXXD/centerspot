import CoreGraphics
import CoreText
import Foundation

/// One export frame (SPEC §7): the background, the title band, the current step's note in Kalam, the board drawn by
/// `BoardRenderer` (D-07, never a second way) and the "Agmen" corner mark (D-38). Video frames, the step PNG and the
/// export preview all draw through it. Not thread-safe: it caches laid-out text, so make one per export.
final class ExportFrame {
    /// The corner mark's words (D-38, D-63).
    static let mark = "Agmen"

    let tactic: Tactic
    let layout: ExportLayout
    /// Where the broadcast camera looks (BR-2); nil for the flat board.
    private let track: CameraTrack?
    private var texts: [String: CTFrame] = [:]

    init(tactic: Tactic, canvas: ExportCanvas, showsTitle: Bool, showsNotes: Bool, camera: BoardCamera = .flat) {
        self.tactic = tactic
        self.layout = ExportLayout.make(canvas, kind: tactic.pitch.kind, showsTitle: showsTitle, showsNote: showsNotes,
                                        broadcast: camera == .broadcast)
        track = camera == .broadcast ? CameraTrack(tactic: tactic) : nil
    }

    /// The move's length on the timeline (phase 0).
    var duration: Double { tactic.phases.first.map(Timeline.duration(of:)) ?? 0 }

    /// The frame at timeline instant `t`.
    func draw(at t: Double, in ctx: CGContext) {
        draw(state: Timeline.state(at: t, in: tactic), target: track?.target(at: t), in: ctx)
    }

    /// The frame for `state` in a y-down context whose units are the canvas's pixels. Through the broadcast camera it
    /// looks where it does when that step is at rest.
    func draw(state: BoardState, in ctx: CGContext) {
        let rest = tactic.phases.first.map { PlaybackTrack.restTimes(of: $0) }?.dropFirst(state.stepIndex).first ?? 0
        draw(state: state, target: track?.target(at: rest), in: ctx)
    }

    /// The flat board sits clear of the text; a broadcast board runs under it, so it goes first and the text on top.
    private func draw(state: BoardState, target: Point?, in ctx: CGContext) {
        ctx.setFillColor(Tokens.Colour.bg.cgColor)
        ctx.fill(CGRect(origin: .zero, size: layout.canvas))
        if target != nil { BoardRenderer.draw(state: state, tactic: tactic, in: ctx, rect: layout.board, options: .init(broadcast: target)) }
        if let box = layout.title { text(tactic.title, face: .title, colour: Tokens.Colour.text, in: box, ctx: ctx) }
        let steps = tactic.phases.first?.steps ?? []
        if let box = layout.note, steps.indices.contains(state.stepIndex),
           let note = steps[state.stepIndex].note, !note.isEmpty {
            text(note, face: .note, colour: Tokens.Colour.text, in: box, ctx: ctx)
        }
        if target == nil { BoardRenderer.draw(state: state, tactic: tactic, in: ctx, rect: layout.board) }
        text(Self.mark, face: .mark, colour: Tokens.Colour.muted, in: layout.mark, ctx: ctx, alignment: .right)
    }

    /// The frame as a new sRGB bitmap of the canvas size.
    func image(state: BoardState) -> CGImage? {
        guard let ctx = Self.bitmap(layout.canvas) else { return nil }
        draw(state: state, in: ctx)
        return ctx.makeImage()
    }

    func image(at t: Double) -> CGImage? {
        guard let ctx = Self.bitmap(layout.canvas) else { return nil }
        draw(at: t, in: ctx)
        return ctx.makeImage()
    }

    /// An opaque sRGB bitmap context, flipped to y-down like the screen.
    static func bitmap(_ size: CGSize) -> CGContext? {
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)
        return ctx
    }

    /// Laid out once per string and box, then reused for every frame that shows it.
    private func text(_ string: String, face: ExportText.Face, colour: RGBA, in box: ExportLayout.TextBox, ctx: CGContext,
                      alignment: CTTextAlignment = .left) {
        let key = "\(face)|\(box.rect)|\(string)"
        let frame = texts[key] ?? {
            let size = ExportText.fittedSize(string, face: face, in: box)
            let made = ExportText.frame(string, face: face, size: size, colour: colour.cgColor, in: box.rect, alignment: alignment)
            texts[key] = made
            return made
        }()
        ExportText.draw(frame, in: box.rect, ctx: ctx)
    }
}
