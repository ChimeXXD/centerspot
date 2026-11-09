import Foundation

extension Comparable {
    /// The value pulled inside `range` (decoding repairs, coordinates, easing input).
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
