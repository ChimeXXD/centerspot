import SwiftUI

/// The library's last move playing on a loop (D-89): the real move from `Timeline` through the Broadcast camera
/// (`CameraTrack`), held on its last step before it starts again, as on the welcome's second page (D-78). With Reduce
/// Motion the players don't move: each step rests and crossfades into the next, and the camera holds one view.
struct MoveLoop: Sendable {
    let tactic: Tactic
    let track: CameraTrack
    /// How long the move plays, holds included.
    let duration: Double
    /// When each step starts (`PlaybackTrack.starts`).
    let starts: [Double]

    /// The hold on the last step before the loop starts again.
    static let endHold = 1.5

    init(tactic: Tactic) {
        self.tactic = tactic
        track = CameraTrack(tactic: tactic)
        duration = LibraryFormat.length(of: tactic)
        starts = tactic.phases.first.map(PlaybackTrack.starts(of:)) ?? []
    }

    var stepCount: Int { starts.count }

    /// Seconds into the move `date` is, `since` the loop began.
    func time(at date: Date, since start: Date) -> Double {
        let loop = duration + Self.endHold
        guard loop > 0 else { return 0 }
        return min(max(0, date.timeIntervalSince(start)).truncatingRemainder(dividingBy: loop), duration)
    }

    /// The step playing at `t` (0-based).
    func step(at t: Double) -> Int {
        starts.lastIndex { $0 <= t } ?? 0
    }

    /// How far through its segment step `index` is at `t`, 0…1.
    func fill(_ index: Int, at t: Double) -> Double {
        tactic.phases.first.map { PlaybackTrack.fill(segment: index, at: t, in: $0) } ?? 0
    }

    func frame(at t: Double, reduceMotion: Bool) -> PlaybackTrack.Frame {
        PlaybackTrack.frame(at: t, in: tactic, reduceMotion: reduceMotion)
    }

    func options(at t: Double, reduceMotion: Bool) -> BoardRenderer.Options {
        let span = reduceMotion ? track.span : nil
        return BoardRenderer.Options(broadcast: span?.middle ?? track.target(at: t), broadcastSpan: span)
    }
}

/// One frame of a `MoveLoop`, drawn by the board's renderer (D-07).
struct MoveLoopBoard: View {
    let loop: MoveLoop
    let t: Double
    let reduceMotion: Bool

    var body: some View {
        let frame = loop.frame(at: t, reduceMotion: reduceMotion), options = loop.options(at: t, reduceMotion: reduceMotion)
        Canvas { context, size in
            context.withCGContext { cg in
                BoardRenderer.draw(state: frame.base, crossfadingTo: frame.next, mix: frame.mix, tactic: loop.tactic, in: cg,
                                   rect: CGRect(origin: .zero, size: size), options: options)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The loop's scrubber: one segment per step, filling as it plays.
struct MoveLoopScrubber: View {
    let loop: MoveLoop
    let t: Double

    var body: some View {
        HStack(spacing: Tokens.Space.s1) {
            ForEach(0..<loop.stepCount, id: \.self) { @Sendable index in
                MoveLoopSegment(fill: loop.fill(index, at: t))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MoveLoopSegment: View {
    let fill: Double

    nonisolated init(fill: Double) {
        self.fill = fill
    }

    var body: some View {
        Capsule()
            .fill(Tokens.Colour.text.color.opacity(0.28))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Tokens.Colour.text.color).frame(width: proxy.size.width * fill)
                }
            }
            .frame(height: 4)
    }
}
