import Foundation

/// A named list of steps. v1 edits the first phase ("Main"); D-20 adds in and out of possession.
struct Phase: Codable, Sendable, Hashable, Identifiable {
    enum ID: String, Codable, Sendable, CaseIterable {
        case main, inPossession, outOfPossession
    }

    /// A tactic has 1…2 phases with unique ids (docs/FORMAT.md).
    static let countRange = 1...2
    /// A phase has 1…40 steps with unique ids (docs/FORMAT.md).
    static let stepCountRange = 1...40

    var id: ID
    var name: String
    var steps: [Step]

    init(id: ID, name: String, steps: [Step]) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}
