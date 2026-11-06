import Foundation

/// One of the two teams. Rendering is fixed by side (D-15): home is filled, away is a ring,
/// so colour is never the only difference.
struct Side: Codable, Sendable, Hashable, Identifiable {
    enum ID: String, Codable, Sendable, CaseIterable {
        case home, away
    }

    /// Kit palette keys (docs/design/UI-BRIEF.md §2). Fills and number inks live in `Design/`.
    enum Colour: String, Codable, Sendable, CaseIterable {
        case blue, red, orange, yellow, green, purple, black, white, sky, maroon
    }

    enum Rendering: Sendable {
        case filled, ring
    }

    var id: ID
    var name: String
    var colour: Colour

    init(id: ID, name: String, colour: Colour) {
        self.id = id
        self.name = name
        self.colour = colour
    }

    /// Not stored in the file: it follows from the side (D-15).
    var rendering: Rendering {
        switch id {
        case .home: .filled
        case .away: .ring
        }
    }

    /// The colour a side gets when its file names an unknown one (docs/FORMAT.md: repair, default).
    static func defaultColour(for id: ID) -> Colour {
        switch id {
        case .home: .blue
        case .away: .orange
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colour = (try? container.decodeIfPresent(Colour.self, forKey: .colour)) ?? Self.defaultColour(for: id)
    }
}
