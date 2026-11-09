import Foundation

/// Play, pause, scrub, loop and speed as a value (D4-1). It turns a monotonic time the screen passes in (seconds,
/// any origin) into the timeline's `t`; it never reads a clock itself (CLAUDE.md rule 2), so tests drive it with
/// plain numbers and the board always draws `Timeline.state(at: t(at: now), in:)`.
struct PlaybackClock: Sendable, Equatable {
    /// The speeds the playback bar offers (UI-BRIEF §4.5).
    static let speeds: [Double] = [0.5, 1]

    /// The move's length, `Timeline.duration(of:)`.
    private(set) var duration: Double
    private(set) var isPlaying = false
    private(set) var loops = false
    private(set) var speed = 1.0
    /// `t` at `anchorTime`; while playing, `t` runs on from here at `speed`.
    private var anchorT: Double
    private var anchorTime = 0.0

    init(duration: Double, t: Double = 0, loops: Bool = false) {
        self.duration = max(duration, 0)
        self.loops = loops
        anchorT = Self.clamp(t, to: self.duration)
    }

    /// The timeline's `t` at `now`: held while paused, wrapped when looping, otherwise stopped at the end.
    func t(at now: Double) -> Double {
        guard isPlaying else { return anchorT }
        let raw = anchorT + max(now - anchorTime, 0) * speed
        guard raw > duration else { return raw }
        guard loops, duration > 0 else { return duration }
        return raw.truncatingRemainder(dividingBy: duration)
    }

    /// Played to the end without looping; the screen pauses there.
    func isFinished(at now: Double) -> Bool {
        isPlaying && !loops && t(at: now) >= duration
    }

    /// Starts from where it is, or from the beginning when it is at the end.
    mutating func play(at now: Double) {
        let t = t(at: now)
        anchor(t >= duration ? 0 : t, at: now)
        isPlaying = true
    }

    mutating func pause(at now: Double) {
        anchor(t(at: now), at: now)
        isPlaying = false
    }

    mutating func toggle(at now: Double) {
        if isPlaying { pause(at: now) } else { play(at: now) }
    }

    /// Jumps to `t`, clamped to the move; playing carries on from there. NaN reads as 0.
    mutating func scrub(to t: Double, at now: Double) {
        anchor(Self.clamp(t, to: duration), at: now)
    }

    /// Speeds below a tenth are refused (a paused clock is `pause`, not speed 0).
    mutating func setSpeed(_ speed: Double, at now: Double) {
        guard speed.isFinite, speed >= 0.1 else { return }
        anchor(t(at: now), at: now)
        self.speed = speed
    }

    mutating func setLoops(_ loops: Bool, at now: Double) {
        anchor(t(at: now), at: now)
        self.loops = loops
    }

    /// The move changed length (an undo while playing); `t` stays inside it.
    mutating func setDuration(_ duration: Double, at now: Double) {
        let t = t(at: now)
        self.duration = max(duration, 0)
        anchor(Self.clamp(t, to: self.duration), at: now)
    }

    private mutating func anchor(_ t: Double, at now: Double) {
        anchorT = t
        anchorTime = now
    }

    private static func clamp(_ t: Double, to duration: Double) -> Double {
        t.isNaN ? 0 : min(max(t, 0), duration)
    }
}
