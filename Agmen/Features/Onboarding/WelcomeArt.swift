import SwiftUI

/// The welcome pages' moving pictures (D-78, mockup `onboarding-*--bc`): the real example move drawn by
/// `BoardRenderer` from `Timeline`, never a picture of it. Page 1 cycles the steps on the flat board with the step
/// chips; page 2 plays it through the Broadcast camera with the scrubber's segments; page 3 plays the 9:16 export frame
/// in Broadcast. Each loops after a short hold and pauses while its page is off screen. With Reduce Motion the players
/// don't move: each step rests and crossfades into the next, and the camera holds one view of the whole move.
struct WelcomeArt: View {
    let page: Int
    let tactic: Tactic
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opened = Date.now
    @State private var track: CameraTrack?
    @State private var clip: ExportFrame?

    /// The hold on the last step before the loop starts again.
    static let endHold = 1.5
    static let boardWidth: CGFloat = 222
    static let broadcastSize = CGSize(width: 393, height: 340)
    static let clipSize = CGSize(width: 227, height: 404)

    private var duration: Double { tactic.phases.first.map(Timeline.duration(of:)) ?? 0 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive)) { context in
            let t = time(at: context.date)
            switch page {
            case 1: steps(at: t)
            case 2: playing(at: t)
            default: clipFrame(at: t)
            }
        }
        .onChange(of: isActive) { if isActive { opened = .now } }
        .onAppear {
            if track == nil { track = CameraTrack(tactic: tactic) }
            if clip == nil { clip = ExportFrame(tactic: tactic, canvas: .vertical, showsTitle: true, showsNotes: true, camera: .broadcast) }
        }
    }

    /// Seconds into the move, looping after `endHold` on the last step.
    private func time(at date: Date) -> Double {
        let loop = duration + Self.endHold
        guard loop > 0 else { return 0 }
        return min(date.timeIntervalSince(opened).truncatingRemainder(dividingBy: loop), duration)
    }

    private func frame(at t: Double) -> PlaybackTrack.Frame {
        PlaybackTrack.frame(at: t, in: tactic, reduceMotion: reduceMotion)
    }

    // MARK: Page 1

    private func steps(at t: Double) -> some View {
        let frame = frame(at: t)
        let height = BoardGeometry.height(forWidth: Self.boardWidth, kind: tactic.pitch.kind)
        return VStack(spacing: Tokens.Space.s3) {
            board(frame, options: .init()).frame(width: Self.boardWidth, height: height)
            HStack(spacing: Tokens.Space.s2) {
                ForEach(Array((tactic.phases.first?.steps ?? []).enumerated()), id: \.offset) { index, step in
                    chip(index, duration: step.duration, on: index == frame.base.stepIndex)
                }
            }
        }
    }

    private func chip(_ index: Int, duration: Double, on: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(index + 1)").font(Tokens.Typeface.headline)
            Text("\(duration.formatted(.number.precision(.fractionLength(1)))) s").font(Tokens.Typeface.caption)
        }
        .foregroundStyle(on ? Tokens.Colour.accentInk.color : Tokens.Colour.muted.color)
        .frame(width: 40, height: 48)
        .background(on ? Tokens.Colour.accent.color : Tokens.Colour.surface2.color,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
    }

    // MARK: Page 2

    private func playing(at t: Double) -> some View {
        let track = track ?? CameraTrack(tactic: tactic)
        let options = BoardRenderer.Options(broadcast: reduceMotion ? track.still : track.target(at: t),
                                            broadcastSpan: reduceMotion ? track.span : nil)
        let steps = tactic.phases.first?.steps.count ?? 0
        return VStack(spacing: Tokens.Space.s3) {
            // Scaled down to fit a 375 pt wide iPhone (SE, mini) instead of overflowing it.
            board(frame(at: t), options: options)
                .aspectRatio(Self.broadcastSize, contentMode: .fit)
                .frame(maxWidth: Self.broadcastSize.width)
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { index in
                    segment(fill: tactic.phases.first.map { PlaybackTrack.fill(segment: index, at: t, in: $0) } ?? 0)
                }
            }
            .frame(width: Self.boardWidth, height: 48)
        }
    }

    private func segment(fill: Double) -> some View {
        Capsule()
            .fill(Tokens.Colour.surface2.color)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Tokens.Colour.accent.color).frame(width: proxy.size.width * fill)
                }
            }
            .frame(height: 6)
    }

    // MARK: Page 3

    private func clipFrame(at t: Double) -> some View {
        let size = Self.clipSize
        return Canvas { context, _ in
            guard let clip else { return }
            context.withCGContext { cg in
                cg.scaleBy(x: size.width / clip.layout.canvas.width, y: size.height / clip.layout.canvas.height)
                // Reduce Motion: each step at rest (the export itself never changes, rule 8; this is only a picture of it).
                if reduceMotion { clip.drawStill(frame(at: t), in: cg) } else { clip.draw(at: t, in: cg) }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Tokens.Colour.surface3.color, lineWidth: 2))
    }

    // MARK: Board

    private func board(_ frame: PlaybackTrack.Frame, options: BoardRenderer.Options) -> some View {
        Canvas { context, size in
            context.withCGContext { cg in
                BoardRenderer.draw(state: frame.base, crossfadingTo: frame.next, mix: frame.mix, tactic: tactic, in: cg,
                                   rect: CGRect(origin: .zero, size: size), options: options)
            }
        }
    }
}
