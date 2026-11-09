import Foundation
import Testing
@testable import CenterSpot

/// D4-1: where each step sits on the timeline (the scrubber's segments, previous and next), and what the board shows
/// at `t` with and without Reduce Motion (CLAUDE.md rule 8).
struct PlaybackTrackTests {
    /// The hero: moves of 1.2, 1.4, 1.2 and 1.2 s, holds of 0.3 s. Steps start at 0, 1.5, 3.2, 4.7 and 6.2; 6.5 s long.
    private let hero: Tactic
    private var phase: Phase { hero.phases[0] }

    init() throws {
        hero = try Fixtures.tactic("overlap-left")
    }

    private func expectClose(_ a: Double, _ b: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(a - b) < 1e-9, "\(a) is not \(b)", sourceLocation: sourceLocation)
    }

    @Test func stepsStartWhereTheTimelineSaysAndRestAfterTheirHold() {
        let starts = PlaybackTrack.starts(of: phase)
        let expected = [0, 1.5, 3.2, 4.7, 6.2]
        #expect(starts.count == 5)
        for (a, b) in zip(starts, expected) { expectClose(a, b) }
        let rests = PlaybackTrack.restTimes(of: phase)
        for (a, b) in zip(rests, expected) { expectClose(a, b + Timeline.hold) }
        expectClose(rests.last ?? 0, Timeline.duration(of: phase))
        // At a rest time the board is the resting step (what the editor shows).
        for (index, rest) in rests.enumerated() {
            #expect(Timeline.state(at: rest, in: hero) == Timeline.restingState(step: index, in: hero), "step \(index + 1)")
        }
    }

    @Test func segmentsFillAsTheirStepPlays() {
        expectClose(PlaybackTrack.fill(segment: 0, at: 0, in: phase), 0)
        expectClose(PlaybackTrack.fill(segment: 0, at: 0.75, in: phase), 0.5)
        expectClose(PlaybackTrack.fill(segment: 0, at: 2, in: phase), 1)
        expectClose(PlaybackTrack.fill(segment: 1, at: 1, in: phase), 0)
        expectClose(PlaybackTrack.fill(segment: 1, at: 2.35, in: phase), 0.5)
        expectClose(PlaybackTrack.fill(segment: 4, at: 6.35, in: phase), 0.5)
        expectClose(PlaybackTrack.fill(segment: 4, at: 6.5, in: phase), 1)
    }

    @Test func aPlaceOnTheScrubberIsATime() {
        // Five equal segments: 0.3 of the way is 50% through step 2's segment.
        expectClose(PlaybackTrack.time(atFraction: 0, in: phase), 0)
        expectClose(PlaybackTrack.time(atFraction: 0.1, in: phase), 0.75)
        expectClose(PlaybackTrack.time(atFraction: 0.3, in: phase), 2.35)
        expectClose(PlaybackTrack.time(atFraction: 1, in: phase), 6.5)
        expectClose(PlaybackTrack.time(atFraction: 7, in: phase), 6.5)
        expectClose(PlaybackTrack.time(atFraction: -1, in: phase), 0)
    }

    @Test func previousAndNextLandOnRestingSteps() {
        expectClose(PlaybackTrack.next(from: 0, in: phase), 0.3)
        expectClose(PlaybackTrack.next(from: 0.3, in: phase), 1.8)
        expectClose(PlaybackTrack.next(from: 2.6, in: phase), 3.5)
        expectClose(PlaybackTrack.next(from: 6.5, in: phase), 6.5)
        expectClose(PlaybackTrack.previous(from: 2.6, in: phase), 1.8)
        // Just after landing on a step, previous goes one further back.
        expectClose(PlaybackTrack.previous(from: 1.85, in: phase), 0.3)
        expectClose(PlaybackTrack.previous(from: 0.3, in: phase), 0)
        expectClose(PlaybackTrack.previous(from: 0, in: phase), 0)
    }

    @Test func scrubbingWithReduceMotionSnapsToTheNearestStep() {
        expectClose(PlaybackTrack.nearestRest(to: 0, in: phase), 0.3)
        expectClose(PlaybackTrack.nearestRest(to: 1.2, in: phase), 1.8)
        expectClose(PlaybackTrack.nearestRest(to: 2.5, in: phase), 1.8)
        expectClose(PlaybackTrack.nearestRest(to: 2.7, in: phase), 3.5)
        expectClose(PlaybackTrack.nearestRest(to: 9, in: phase), 6.5)
    }

    @Test func withoutReduceMotionTheBoardIsTheTimeline() {
        for t in [0, 0.9, 2.4, 4.0, 6.5] {
            let frame = PlaybackTrack.frame(at: t, in: hero, reduceMotion: false)
            #expect(frame.base == Timeline.state(at: t, in: hero))
            #expect(frame.next == nil && frame.mix == 0)
        }
    }

    @Test func reduceMotionStepsThroughWithCrossfades() {
        // Mid-move from step 2 to 3 (1.8…3.2): no token moves, step 2 rests.
        let still = PlaybackTrack.frame(at: 2.4, in: hero, reduceMotion: true)
        #expect(still.base == Timeline.restingState(step: 1, in: hero))
        #expect(still.next == nil && still.mix == 0)
        // The last 0.3 s of the move crossfade into step 3.
        let fading = PlaybackTrack.frame(at: 3.05, in: hero, reduceMotion: true)
        #expect(fading.base == Timeline.restingState(step: 1, in: hero))
        #expect(fading.next == Timeline.restingState(step: 2, in: hero))
        expectClose(fading.mix, 0.5)
        // Step 3 has arrived when its own span starts.
        let arrived = PlaybackTrack.frame(at: 3.2, in: hero, reduceMotion: true)
        #expect(arrived.base == Timeline.restingState(step: 2, in: hero))
        #expect(arrived.next == nil)
        // The last step never fades anywhere.
        let end = PlaybackTrack.frame(at: 6.5, in: hero, reduceMotion: true)
        #expect(end.base == Timeline.restingState(step: 4, in: hero) && end.next == nil)
    }

    @Test func reduceMotionNeverShowsATokenBetweenSteps() {
        let rests = (0..<phase.steps.count).map { Timeline.restingState(step: $0, in: hero).positions }
        for i in 0...650 {
            let frame = PlaybackTrack.frame(at: Double(i) / 100, in: hero, reduceMotion: true)
            #expect(rests.contains(frame.base.positions), "t = \(Double(i) / 100)")
            if let next = frame.next { #expect(rests.contains(next.positions)) }
        }
    }
}
