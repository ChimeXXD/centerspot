import Foundation

/// A line drawn on one step only, faded in during the step's hold (SPEC §2). Kinds differ by line style,
/// not only colour (D-15): run solid, pass dashed, dribble wavy, press a short double chevron.
struct Arrow: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case run, pass, dribble, press
    }

    var kind: Kind
    /// 2…200 points, the same limit as a run (`Path.pointCountRange`).
    var points: [Point]

    init(kind: Kind, points: [Point]) {
        self.kind = kind
        self.points = points
    }
}
