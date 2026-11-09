import Foundation

/// Easing curves for the timeline (SPEC §3).
enum Easing {
    /// Ease-in-out cubic on 0…1; input outside the range is clamped.
    static func inOutCubic(_ progress: Double) -> Double {
        let p = progress.clamped(to: 0...1)
        if p < 0.5 {
            return 4 * p * p * p
        }
        let q = -2 * p + 2
        return 1 - q * q * q / 2
    }
}
