import SwiftUI

/// The export preview (UI-BRIEF §4.6): the export itself, playing at the chosen ratio and drawn by `ExportFrame`, with
/// dashed caption safe zones over it (preview only, D-11). With Reduce Motion it holds the step on screen still
/// (CLAUDE.md rule 8: in-app playback changes, the video never does).
struct ExportPreview: View {
    let model: ExportModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frames = FrameCache()
    @State private var opened = Date.now

    /// The preview box; the canvas is fitted inside it.
    static let box = CGSize(width: 150, height: 266)

    var body: some View {
        let canvas = canvasSize
        let scale = min(Self.box.width / canvas.width, Self.box.height / canvas.height)
        let size = CGSize(width: canvas.width * scale, height: canvas.height * scale)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { context in
            Canvas { gc, _ in
                gc.withCGContext { cg in
                    cg.scaleBy(x: scale, y: scale)
                    draw(at: context.date, in: cg)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay { safeZones(size) }
        .overlay { veil }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(width: Self.box.width, height: Self.box.height)
        .accessibilityElement()
        .accessibilityLabel(model.preset.video != nil && model.camera == .broadcast
                            ? "Preview, \(model.preset.title), broadcast camera" : "Preview, \(model.preset.title)")
        .accessibilityIdentifier("export.preview")
    }

    private var playing: Bool { model.preset.video != nil && !reduceMotion && model.phase == .choosing }

    private var canvasSize: CGSize {
        if let format = model.preset.video { return CGSize(width: format.pixelSize.width, height: format.pixelSize.height) }
        return CGSize(width: model.imageSize.width, height: model.imageSize.height)
    }

    private func draw(at date: Date, in cg: CGContext) {
        if model.preset == .image, model.imageKind == .lineup {
            frames.lineup(model.tactic).draw(in: cg)
            return
        }
        let canvas: ExportCanvas = model.preset.video?.canvas ?? .image(width: model.imageSize.width)
        let frame = frames.frame(model, canvas: canvas)
        guard playing else {
            frame.draw(state: Timeline.restingState(step: model.stepIndex, in: model.tactic), in: cg)
            return
        }
        // Loops the whole export, stills included, at the export's own frame times.
        let total = ExportClock.frameCount(duration: frame.duration)
        let index = Int(date.timeIntervalSince(opened) * Double(ExportClock.fps)) % max(total, 1)
        frame.draw(at: ExportClock.time(ofFrame: index, duration: frame.duration), in: cg)
    }

    /// Where platform buttons and captions sit over a vertical clip, and a title-safe margin on the others.
    @ViewBuilder private func safeZones(_ size: CGSize) -> some View {
        if let format = model.preset.video {
            let insets = format == .vertical
                ? EdgeInsets(top: 0.12, leading: 0.06, bottom: 0.2, trailing: 0.15)
                : EdgeInsets(top: 0.06, leading: 0.06, bottom: 0.06, trailing: 0.06)
            Rectangle()
                .stroke(Tokens.Colour.text.color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .padding(EdgeInsets(top: insets.top * size.height, leading: insets.leading * size.width,
                                    bottom: insets.bottom * size.height, trailing: insets.trailing * size.width))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// While rendering: the preview dims and a bar fills along its foot (the mockup's rendering state).
    @ViewBuilder private var veil: some View {
        if case .rendering = model.phase {
            ZStack(alignment: .bottom) {
                Tokens.Colour.bg.color.opacity(0.55)
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(Tokens.Colour.accent.color).frame(width: proxy.size.width * model.progress)
                        }
                    }
                    .padding(Tokens.Space.s2)
            }
            .accessibilityHidden(true)
        }
    }
}

/// The preview's `ExportFrame`, kept while the settings stay the same so text is laid out once, not every frame.
@MainActor
private final class FrameCache {
    private var key: String?
    private var cached: ExportFrame?
    private var card: LineupCard?

    func frame(_ model: ExportModel, canvas: ExportCanvas) -> ExportFrame {
        let camera = model.preset.video == nil ? BoardCamera.flat : model.camera
        let key = "\(canvas)|\(model.showsTitle)|\(model.showsNotes)|\(camera)"
        if key == self.key, let cached { return cached }
        let made = ExportFrame(tactic: model.tactic, canvas: canvas, showsTitle: model.showsTitle,
                               showsNotes: model.showsNotes, camera: camera)
        self.key = key
        cached = made
        return made
    }

    func lineup(_ tactic: Tactic) -> LineupCard {
        if let card { return card }
        let made = LineupCard(tactic)
        card = made
        return made
    }
}
