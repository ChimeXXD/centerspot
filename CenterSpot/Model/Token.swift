import Foundation

/// Something on the board: a player, the ball, a cone or a marker (SPEC §2).
struct Token: Codable, Sendable, Hashable, Identifiable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case player, ball, cone, marker
    }

    /// Shirt numbers are clamped to 0…99 on read (docs/FORMAT.md).
    static let numberRange = 0...99
    /// Names are truncated to 24 characters on read (docs/FORMAT.md).
    static let maxNameLength = 24

    var id: String
    var kind: Kind
    /// Required for a player; a player without a side is refused.
    var side: Side.ID?
    var number: Int?
    var name: String?
    /// An id from `presets/roles.json`; an unknown one is dropped on read.
    var roleID: String?

    init(
        id: String,
        kind: Kind,
        side: Side.ID? = nil,
        number: Int? = nil,
        name: String? = nil,
        roleID: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.side = side
        self.number = number
        self.name = name
        self.roleID = roleID
    }
}
