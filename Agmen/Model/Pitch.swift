import Foundation

/// The playing surface. Its kind sets the aspect ratio; positions stay normalised (D-05).
struct Pitch: Codable, Sendable, Hashable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case full, sevenASide, fiveASide

        /// Length (goal to goal) and width in metres (SPEC §2).
        var size: (length: Double, width: Double) {
            switch self {
            case .full: (105, 68)
            case .sevenASide: (60, 40)
            case .fiveASide: (40, 25)
            }
        }
    }

    enum Style: String, Codable, Sendable, CaseIterable {
        case stripes, plain
    }

    var kind: Kind
    var style: Style

    init(kind: Kind, style: Style = .stripes) {
        self.kind = kind
        self.style = style
    }

    /// An unknown kind is refused (docs/FORMAT.md). The style is cosmetic, so a missing or unknown one
    /// falls back to stripes instead of refusing the file.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        style = (try? container.decodeIfPresent(Style.self, forKey: .style)) ?? .stripes
    }
}
