import Foundation

/// Where the broadcast camera looks at `t` (D-66, D-76): the ball, or with no ball the middle of the players moving in
/// that step, smoothed so a pass glides across instead of whipping the view. Built once from the tactic, sampled
/// `rate` times a second, and a pure function of it like `Timeline` (rule 2), so playback, scrubbing and export frame
/// the same view at the same `t`. How far the view may pan (the pitch's edges) is the renderer's business.
struct CameraTrack: Sendable, Equatable {
    /// Samples per second, the video's frame rate (D-11).
    static let rate = 30.0
    /// The Gaussian's spread in seconds: the camera starts drifting toward a pass a little before it is played and
    /// settles a little after, the way a broadcast camera operator reads the game.
    static let smoothing = 0.4

    /// The smoothed target at each sample: sample k is at `min(k / rate, duration)`, so the last one is the move's end.
    private let targets: [Point]
    private let duration: Double
    /// Reduce Motion (D-76): one view for the whole move, the middle of everywhere the subject goes.
    let still: Point

    init(tactic: Tactic, phaseIndex: Int = 0) {
        guard tactic.phases.indices.contains(phaseIndex) else {
            (targets, duration, still) = ([.centre], 0, .centre)
            return
        }
        let duration = Timeline.duration(of: tactic.phases[phaseIndex])
        let count = Int((duration * Self.rate).rounded(.up)) + 1
        let raw = (0..<count).map { Self.subject(at: Self.time(of: $0, duration: duration), in: tactic, phaseIndex: phaseIndex) }
        // No subject (nobody moving): hold the last one; before the first, wait on it; never any: the players' middle.
        let first = raw.lazy.compactMap { $0 }.first ?? Self.middleOfPlayers(in: tactic, phaseIndex: phaseIndex) ?? .centre
        var last = first
        let held = raw.map { subject -> Point in
            if let subject { last = subject }
            return last
        }
        self.duration = duration
        targets = Self.smoothed(held)
        let xs = held.map(\.x), ys = held.map(\.y)
        still = Point(x: ((xs.min() ?? 0.5) + (xs.max() ?? 0.5)) / 2, y: ((ys.min() ?? 0.5) + (ys.max() ?? 0.5)) / 2)
    }

    /// The point on the pitch the camera centres on at `t` (clamped to the move; NaN reads as 0), between samples.
    func target(at t: Double) -> Point {
        let time = t.isNaN ? 0 : min(max(t, 0), duration)
        let k = min(Int(time * Self.rate), targets.count - 1)
        guard k + 1 < targets.count else { return targets[k] }
        let t0 = Self.time(of: k, duration: duration), t1 = Self.time(of: k + 1, duration: duration)
        let f = t1 > t0 ? (time - t0) / (t1 - t0) : 0
        let a = targets[k], b = targets[k + 1]
        return Point(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    /// What the camera follows at `t`, before smoothing: the first ball; with no ball, the middle of the players whose
    /// next step puts them somewhere else; nil when no one moves (the last step, or a step where everyone stands).
    static func subject(at t: Double, in tactic: Tactic, phaseIndex: Int = 0) -> Point? {
        let state = Timeline.state(at: t, in: tactic, phaseIndex: phaseIndex)
        if let ball = tactic.tokens.first(where: { $0.kind == .ball }) { return state.positions[ball.id] }
        guard tactic.phases.indices.contains(phaseIndex) else { return nil }
        let steps = tactic.phases[phaseIndex].steps, index = state.stepIndex
        guard index + 1 < steps.count else { return nil }
        let resting = Timeline.restingState(step: index, in: tactic, phaseIndex: phaseIndex).positions
        let next = steps[index + 1].positions
        let movers = tactic.tokens.filter { token in
            guard token.kind == .player, let from = resting[token.id], let to = next[token.id] else { return false }
            return hypot(to.x - from.x, to.y - from.y) > 1e-6
        }
        return middle(of: movers.compactMap { state.positions[$0.id] })
    }

    private static func time(of sample: Int, duration: Double) -> Double {
        min(Double(sample) / rate, duration)
    }

    private static func middleOfPlayers(in tactic: Tactic, phaseIndex: Int) -> Point? {
        let positions = Timeline.state(at: 0, in: tactic, phaseIndex: phaseIndex).positions
        return middle(of: tactic.tokens.filter { $0.kind == .player }.compactMap { positions[$0.id] })
    }

    private static func middle(of points: [Point]) -> Point? {
        guard !points.isEmpty else { return nil }
        let n = Double(points.count)
        return Point(x: points.reduce(0) { $0 + $1.x } / n, y: points.reduce(0) { $0 + $1.y } / n)
    }

    /// A Gaussian blur along time, `smoothing` seconds wide; past either end the first or last sample repeats.
    private static func smoothed(_ points: [Point]) -> [Point] {
        let sigma = smoothing * rate, reach = Int((3 * sigma).rounded(.up))
        let weights = (-reach...reach).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
        let total = weights.reduce(0, +)
        return points.indices.map { i in
            var x = 0.0, y = 0.0
            for (j, w) in zip(-reach...reach, weights) {
                let p = points[min(max(i + j, 0), points.count - 1)]
                x += p.x * w
                y += p.y * w
            }
            return Point(x: x / total, y: y / total)
        }
    }
}
