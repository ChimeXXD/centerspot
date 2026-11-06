import Foundation

/// A generic football role in our own words, from `presets/roles.json` (D-13, D-14).
struct Role: Codable, Sendable, Hashable, Identifiable {
    enum Line: String, Codable, Sendable, CaseIterable {
        case gk, def, mid, att
    }

    let id: String
    /// Two or three letters for tight spaces ("FB").
    let short: String
    let name: String
    let line: Line
}
