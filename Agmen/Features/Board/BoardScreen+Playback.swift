import QuartzCore
import SwiftUI

/// Playing the move (D4-1): `PlaybackClock` turns the screen's monotonic time into `t`, and the board draws
/// `PlaybackTrack.frame(at: t)` (the timeline, or resting steps with crossfades under Reduce Motion, rule 8).
extension BoardScreen {
    /// Monotonic seconds for the clock. Only the screen reads a clock; `PlaybackClock` and `Timeline` never do (rule 2).
    static var now: Double { CACurrentMediaTime() }

    var phaseDuration: Double { tactic.phases.first.map(Timeline.duration(of:)) ?? 0 }

    @ViewBuilder var playbackBar: some View {
        if let phase = tactic.phases.first {
            TimelineView(.animation(minimumInterval: nil, paused: !clock.isPlaying)) { _ in
                PlaybackBar(
                    phase: phase, t: clock.t(at: Self.now), isPlaying: clock.isPlaying, loops: clock.loops, speed: clock.speed,
                    onToggle: { clock.toggle(at: Self.now) },
                    onPrevious: { jump(PlaybackTrack.previous(from: clock.t(at: Self.now), in: phase)) },
                    onNext: { jump(PlaybackTrack.next(from: clock.t(at: Self.now), in: phase)) },
                    onLoop: { clock.setLoops(!clock.loops, at: Self.now) },
                    onSpeed: { clock.setSpeed($0, at: Self.now) },
                    onScrub: { scrubbed(to: $0, ended: $1, in: phase) }
                )
            }
        }
    }

    /// Play in the toolbar: from the step on screen (from the start when that's the last one), keeping the last
    /// loop and speed choices.
    func startPlayback() {
        guard let phase = tactic.phases.first, !tactic.tokens.isEmpty else { return }
        let now = Self.now
        let starts = PlaybackTrack.starts(of: phase)
        let from = current < starts.count - 1 ? starts[current] : 0
        var next = PlaybackClock(duration: Timeline.duration(of: phase), t: from)
        next.setLoops(clock.loops, at: now)
        next.setSpeed(clock.speed, at: now)
        next.play(at: now)
        clock = next
        scrub = (false, false)  // a scrub cut off without an end (the bar left mid-drag) must not carry over
        toast = nil  // its Undo would edit the tactic mid-playback
        dragPreview = nil
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            showsStepActions = false
            mode = .playing
        }
    }

    /// Done: back to editing on the step playback stopped on.
    func stopPlayback() {
        let now = Self.now
        let t = clock.t(at: now)
        clock.pause(at: now)
        withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) {
            stepIndex = Timeline.state(at: t, in: tactic).stepIndex
            mode = .editing
        }
    }

    /// Previous and next land on a resting step and keep playing or paused as they were.
    private func jump(_ t: Double) {
        clock.scrub(to: t, at: Self.now)
    }

    /// Holding the scrubber pauses; letting go plays on if it was playing. Reduce Motion snaps to the nearest step.
    private func scrubbed(to fraction: Double, ended: Bool, in phase: Phase) {
        let now = Self.now
        if !scrub.active {
            scrub = (clock.isPlaying, true)
            clock.pause(at: now)
        }
        var t = PlaybackTrack.time(atFraction: fraction, in: phase)
        if reduceMotion { t = PlaybackTrack.nearestRest(to: t, in: phase) }
        clock.scrub(to: t, at: now)
        guard ended else { return }
        if scrub.resumes { clock.play(at: now) }
        scrub = (false, false)
    }

    /// Without Loop, playback stops on the last frame and the button turns back to Play.
    func pauseAtTheEnd() async {
        guard mode == .playing, clock.isPlaying, !clock.loops, clock.speed > 0 else { return }
        let remaining = (clock.duration - clock.t(at: Self.now)) / clock.speed
        try? await Task.sleep(for: .seconds(max(remaining, 0) + 0.02))
        guard !Task.isCancelled, clock.isFinished(at: Self.now) else { return }
        clock.pause(at: Self.now)
    }

    /// Tapping the pitch while playing pauses (UI-BRIEF §4.5); while drawing, a tap is a stroke too short to keep.
    func tapBoard(_ id: String?) {
        switch mode {
        case .editing: tap(id)
        case .playing: if clock.isPlaying { clock.pause(at: Self.now) }
        case .drawing: break
        }
    }
}
