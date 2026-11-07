import Foundation

/// A line joining players of one side in order, e.g. a back three (D-65). It holds token ids, not points, so its
/// corners follow the players wherever the timeline puts them. Drawn in that side's colour.
struct ShapeLine: Codable, Sendable, Hashable, Identifiable {
    /// A line names at most a whole team (docs/FORMAT.md: more refuses the file).
    static let maxTokens = 11
    /// Fewer players than this left after repair, and the line is dropped.
    static let minTokens = 2

    var id: String
    /// Player ids in the order the line joins them.
    var tokens: [String]

    init(id: String, tokens: [String]) {
        self.id = id
        self.tokens = tokens
    }
}
