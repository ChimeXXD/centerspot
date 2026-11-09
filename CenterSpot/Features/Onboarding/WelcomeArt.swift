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
    /// How much bigger than the phone's the picture is drawn (1 on a phone; more on an iPad, sized by `WelcomeView`).
    /// The pictures are drawn at that size, not scaled up afterwards, so they stay sharp.
    var scale: CGFloat = 1
    /// The picture sits inside a wider page (an iPad, at any `scale`): pages 2 and 3 hold the whole pitch's width.
    var wide = false
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
        let width = Self.boardWidth * scale
        let height = BoardGeometry.height(forWidth: width, kind: tactic.pitch.kind)
        return VStack(spacing: Tokens.Space.s3) {
            board(frame, options: .init()).frame(width: width, height: height)
            HStack(spacing: Tokens.Space.s2) {
                ForEach(Array((tactic.phases.first?.steps ?? []).enumerated()), id: \.offset) { index, step in
                    chip(index, duration: step.duration, on: index == frame.base.stepIndex)
                }
            }
        }
    }

    /// The chips grow with the picture on an iPad, up to half again, so they stay in step with the board above them.
    private var chipScale: CGFloat { min(scale, 1.5) }

    private func chip(_ index: Int, duration: Double, on: Bool) -> some View {
        VStack(spacing: 0) {
            // Fixed sizes: the chips are part of the picture, sized with it (the words below follow Dynamic Type).
            Text("\(index + 1)").font(.custom(Tokens.Typeface.uiName, fixedSize: 17 * chipScale).weight(.bold))
            Text("\(duration.formatted(.number.precision(.fractionLength(1)))) s")
                .font(.custom(Tokens.Typeface.uiName, fixedSize: 12 * chipScale).weight(.medium))
        }
        .foregroundStyle(on ? Tokens.Colour.accentInk.color : Tokens.Colour.muted.color)
        .frame(width: 40 * chipScale, height: 48 * chipScale)
        .background(on ? Tokens.Colour.accent.color : Tokens.Colour.surface2.color,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.tile * chipScale))
    }

    // MARK: Page 2

    private func playing(at t: Double) -> some View {
        let track = track ?? CameraTrack(tactic: tactic)
        // On an iPad the picture sits inside the page, so a pitch running off its sides shows a hard cut: it holds one
        // view of the whole pitch's width over the move instead of following the ball (Chime, 8 Nov).
        let span: CameraTrack.Span? = wide ? Self.wideSpan(of: track) : reduceMotion ? track.span : nil
        let options = BoardRenderer.Options(broadcast: span?.middle ?? track.target(at: t), broadcastSpan: span)
        let steps = tactic.phases.first?.steps.count ?? 0
        return VStack(spacing: Tokens.Space.s3) {
            // Scaled down to fit a 375 pt wide iPhone (SE, mini) instead of overflowing it.
            board(frame(at: t), options: options)
                .aspectRatio(Self.broadcastSize, contentMode: .fit)
                .frame(maxWidth: Self.broadcastSize.width * scale)
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { index in
                    segment(fill: tactic.phases.first.map { PlaybackTrack.fill(segment: index, at: t, in: $0) } ?? 0)
                }
            }
            .frame(width: Self.boardWidth * scale, height: 48)
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
        let size = CGSize(width: Self.clipSize.width * scale, height: Self.clipSize.height * scale)
        return Canvas { context, _ in
            guard let clip else { return }
            let wideSpan = wide ? Self.wideSpan(of: track ?? CameraTrack(tactic: tactic)) : nil
            context.withCGContext { cg in
                cg.scaleBy(x: size.width / clip.layout.canvas.width, y: size.height / clip.layout.canvas.height)
                // Reduce Motion: each step at rest (the export itself never changes, rule 8; this is only a picture of it).
                // On an iPad the clip holds the whole pitch's width, as page 2 does (Chime, 8 Nov); the video doesn't.
                if let wideSpan {
                    clip.draw(frame(at: t), framing: wideSpan, in: cg)
                } else if reduceMotion {
                    clip.drawStill(frame(at: t), in: cg)
                } else {
                    clip.draw(at: t, in: cg)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile * scale))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.tile * scale).stroke(Tokens.Colour.surface3.color, lineWidth: 2))
    }

    /// The whole pitch's width over the move's depth: the iPad's still view on pages 2 and 3.
    private static func wideSpan(of track: CameraTrack) -> CameraTrack.Span {
        CameraTrack.Span(min: Point(x: 0, y: track.span.min.y), max: Point(x: 1, y: track.span.max.y))
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
