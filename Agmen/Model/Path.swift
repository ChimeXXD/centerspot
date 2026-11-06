import Foundation

/// A drawn run: the line a token follows from this step's position to the next step's (SPEC §2, D-08).
/// On read it is anchored at both ends (D-27), so playback never jumps.
///
/// Inside SwiftUI files of this module, `Path` means this type; write `SwiftUI.Path` for a shape path.
struct Path: Codable, Sendable, Hashable {
    /// A run or arrow has 2…200 points (docs/FORMAT.md).
    static let pointCountRange = 2...200

    var points: [Point]

    init(points: [Point]) {
        self.points = points
    }
}
