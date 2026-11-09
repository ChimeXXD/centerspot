import Foundation

/// Where each step sits on the timeline, for the playback bar (D4-1, UI-BRIEF §4.5): one equal segment per step,
/// previous and next, and the board to show at `t` with or without Reduce Motion (CLAUDE.md rule 8). Pure, like
/// `Timeline`, which it reads.
enum PlaybackTrack {
    /// With Reduce Motion, each step crossfades into the next over this long (SPEC §8).
    static let crossfade = 0.3
    /// Previous within this long after landing on a step goes one step further back, like a media player.
    static let previousSlack = 0.25

    /// The board at an instant of playback: `base`, with `next` drawn over it at `mix` opacity while crossfading.
    struct Frame: Equatable, Sendable {
        var base: BoardState
        var next: BoardState?
        var mix: Double
    }

    /// When each step's hold begins. Step k spans `starts[k]` to `starts[k + 1]` (the last one to the end).
    static func starts(of phase: Phase) -> [Double] {
        var start = 0.0
        return phase.steps.map { step in
            defer { start += Timeline.hold + step.duration }
            return start
        }
    }

    /// When each step is at rest, its arrows shown (`Timeline.restingState`): the end of its hold.
    static func restTimes(of phase: Phase) -> [Double] {
        starts(of: phase).map { $0 + Timeline.hold }
    }

    /// How far through its step's span `t` is, 0…1: the fill of that step's segment on the scrubber.
    static func fill(segment index: Int, at t: Double, in phase: Phase) -> Double {
        guard let span = span(index, in: phase) else { return 0 }
        guard span.upperBound > span.lowerBound else { return t >= span.upperBound ? 1 : 0 }
        return ((t - span.lowerBound) / (span.upperBound - span.lowerBound)).clamped(to: 0...1)
    }

    /// The time at a place on the scrubber (0…1 across equal step segments).
    static func time(atFraction fraction: Double, in phase: Phase) -> Double {
        let count = phase.steps.count
        guard count > 0 else { return 0 }
        let scaled = (fraction.isNaN ? 0 : fraction.clamped(to: 0...1)) * Double(count)
        let index = min(Int(scaled), count - 1)
        guard let span = span(index, in: phase) else { return 0 }
        return span.lowerBound + (scaled - Double(index)) * (span.upperBound - span.lowerBound)
    }

    /// The next step at rest after `t`, else the end.
    static func next(from t: Double, in phase: Phase) -> Double {
        restTimes(of: phase).first { $0 > t + 1e-6 } ?? Timeline.duration(of: phase)
    }

    /// The step at rest before `t` (one further back just after landing on one), else the start.
    static func previous(from t: Double, in phase: Phase) -> Double {
        restTimes(of: phase).last { $0 < t - previousSlack } ?? 0
    }

    /// The resting step nearest `t` (the scrubber snaps there with Reduce Motion); ties go to the earlier step.
    static func nearestRest(to t: Double, in phase: Phase) -> Double {
        restTimes(of: phase).min { abs($0 - t) < abs($1 - t) } ?? 0
    }

    /// What the board shows at `t`. Without Reduce Motion it is the timeline. With it, tokens never move: each step
    /// rests, then crossfades into the next over the last `crossfade` seconds of its move, so the length is unchanged.
    /// Export never calls this (rule 8).
    static func frame(at t: Double, in tactic: Tactic, reduceMotion: Bool, phaseIndex: Int = 0) -> Frame {
        let state = Timeline.state(at: t, in: tactic, phaseIndex: phaseIndex)
        guard reduceMotion, tactic.phases.indices.contains(phaseIndex) else { return Frame(base: state, next: nil, mix: 0) }
        let phase = tactic.phases[phaseIndex]
        let index = state.stepIndex
        let base = Timeline.restingState(step: index, in: tactic, phaseIndex: phaseIndex)
        guard index + 1 < phase.steps.count, let span = span(index, in: phase) else { return Frame(base: base, next: nil, mix: 0) }
        let fade = min(crossfade, phase.steps[index].duration)
        let time = t.isNaN ? 0 : t
        guard fade > 0, time > span.upperBound - fade else { return Frame(base: base, next: nil, mix: 0) }
        let next = Timeline.restingState(step: index + 1, in: tactic, phaseIndex: phaseIndex)
        return Frame(base: base, next: next, mix: ((time - (span.upperBound - fade)) / fade).clamped(to: 0...1))
    }

    /// Step `index`'s span on the timeline: its hold and move, or for the last step its final hold.
    private static func span(_ index: Int, in phase: Phase) -> ClosedRange<Double>? {
        let starts = starts(of: phase)
        guard starts.indices.contains(index) else { return nil }
        let end = index + 1 < starts.count ? starts[index + 1] : Timeline.duration(of: phase)
        return starts[index]...max(end, starts[index])
    }
}
