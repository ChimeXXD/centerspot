import Foundation
import Testing
@testable import CenterSpot

/// D4-1: the playback clock turns a monotonic time the screen passes in into the timeline's `t` (CLAUDE.md rule 2).
struct PlaybackClockTests {
    /// A 6.5 s move, like the hero (5 steps: 1.2 + 1.4 + 1.2 + 1.2 s of moves plus five 0.3 s holds).
    private let duration = 6.5

    private func expectClose(_ a: Double, _ b: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(a - b) < 1e-9, "\(a) is not \(b)", sourceLocation: sourceLocation)
    }

    @Test func pausedHoldsItsTime() {
        let clock = PlaybackClock(duration: duration, t: 2)
        #expect(!clock.isPlaying)
        expectClose(clock.t(at: 100), 2)
        expectClose(clock.t(at: 900), 2)
    }

    @Test func playingAdvancesWithTheTimePassedIn() {
        var clock = PlaybackClock(duration: duration)
        clock.play(at: 50)
        expectClose(clock.t(at: 50), 0)
        expectClose(clock.t(at: 51.25), 1.25)
        clock.pause(at: 52)
        expectClose(clock.t(at: 70), 2)
        clock.play(at: 80)
        expectClose(clock.t(at: 80.5), 2.5)
    }

    @Test func withoutLoopItStopsAtTheEndAndSaysSo() {
        var clock = PlaybackClock(duration: duration)
        clock.play(at: 0)
        #expect(!clock.isFinished(at: 6.4))
        expectClose(clock.t(at: 9), duration)
        #expect(clock.isFinished(at: 9))
    }

    @Test func loopWrapsToTheStart() {
        var clock = PlaybackClock(duration: duration)
        clock.setLoops(true, at: 0)
        clock.play(at: 0)
        expectClose(clock.t(at: 7.5), 1)
        expectClose(clock.t(at: 6.5 * 3 + 0.25), 0.25)
        #expect(!clock.isFinished(at: 100))
    }

    @Test func turningLoopOnAtTheEndDoesNotJump() {
        var clock = PlaybackClock(duration: duration)
        clock.play(at: 0)
        clock.setLoops(true, at: 20)  // played past the end without looping: holds the last frame
        expectClose(clock.t(at: 20), duration)
        clock.setLoops(false, at: 21)
        expectClose(clock.t(at: 21), 1)
    }

    @Test func scrubClampsAndKeepsPlaying() {
        var clock = PlaybackClock(duration: duration)
        clock.scrub(to: -3, at: 0)
        expectClose(clock.t(at: 0), 0)
        clock.scrub(to: 40, at: 0)
        expectClose(clock.t(at: 0), duration)
        clock.scrub(to: .nan, at: 0)
        expectClose(clock.t(at: 0), 0)
        clock.play(at: 10)
        clock.scrub(to: 3, at: 11)
        #expect(clock.isPlaying)
        expectClose(clock.t(at: 11.5), 3.5)
    }

    @Test func playFromTheEndRestarts() {
        var clock = PlaybackClock(duration: duration, t: 6.5)
        clock.play(at: 30)
        expectClose(clock.t(at: 30), 0)
        expectClose(clock.t(at: 31), 1)
    }

    @Test func halfSpeedHalvesTheRate() {
        var clock = PlaybackClock(duration: duration)
        clock.play(at: 0)
        clock.setSpeed(0.5, at: 2)
        expectClose(clock.t(at: 2), 2)
        expectClose(clock.t(at: 4), 3)
        clock.setSpeed(1, at: 4)
        expectClose(clock.t(at: 5), 4)
    }

    @Test func aShorterMoveKeepsTFitting() {
        var clock = PlaybackClock(duration: duration, t: 6)
        clock.setDuration(2, at: 0)
        expectClose(clock.t(at: 0), 2)
        expectClose(clock.duration, 2)
    }

    @Test func toggleSwitchesBetweenPlayAndPause() {
        var clock = PlaybackClock(duration: duration)
        clock.toggle(at: 0)
        #expect(clock.isPlaying)
        clock.toggle(at: 1)
        #expect(!clock.isPlaying)
        expectClose(clock.t(at: 5), 1)
    }

    @Test func sameInputSameOutput() {
        var a = PlaybackClock(duration: duration)
        var b = PlaybackClock(duration: duration)
        a.play(at: 3)
        b.play(at: 3)
        #expect(a == b)
        #expect(a.t(at: 4.2) == b.t(at: 4.2))
    }

    @Test func aClockCanStartLooping() {
        var clock = PlaybackClock(duration: duration, loops: true)
        clock.play(at: 0)
        #expect(clock.loops)
        #expect(abs(clock.t(at: duration + 1) - 1) < 1e-9, "wraps instead of stopping at the end")
    }
}
