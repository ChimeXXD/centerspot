import Foundation

/// Which instant of the move each video frame shows (SPEC §7, D-11): a 0.5 s lead-in still of the board at t = 0, the
/// move at 30 fps ending exactly on its last instant, then a 1 s end still. Pure, like `Timeline`, which the frames
/// read, so two exports of one tactic are the same frames.
enum ExportClock {
    static let fps = 30
    static let leadIn = 0.5
    static let endStill = 1.0

    static var leadInFrames: Int { Int((leadIn * Double(fps)).rounded()) }
    static var endFrames: Int { Int((endStill * Double(fps)).rounded()) }

    /// Frames for the move itself: enough to reach `duration` (a part frame rounds up, so the total is
    /// `30 × (0.5 + duration + 1.0)` + 0…1).
    static func moveFrames(duration: Double) -> Int {
        // The small slack keeps 6.5 × 30 = 195.00000000000003 from becoming 196.
        max(0, Int((duration * Double(fps) - 1e-9).rounded(.up)))
    }

    static func frameCount(duration: Double) -> Int {
        leadInFrames + moveFrames(duration: duration) + endFrames
    }

    /// The video's length in seconds.
    static func length(duration: Double) -> Double {
        Double(frameCount(duration: duration)) / Double(fps)
    }

    /// The timeline instant frame `index` shows: 0 through the lead-in, then 1/30 s further each frame (the last
    /// move frame lands on `duration`), then `duration` through the end still.
    static func time(ofFrame index: Int, duration: Double) -> Double {
        let move = index - leadInFrames + 1
        guard move > 0 else { return 0 }
        guard move <= moveFrames(duration: duration) else { return duration }
        return min(Double(move) / Double(fps), duration)
    }
}
