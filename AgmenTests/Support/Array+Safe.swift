import Foundation

extension Array {
    /// The element at `index`, or nil when it is out of range, so a test fails with a message instead of crashing:
    /// `try #require(steps[safe: 3])`.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
