import Foundation

/// The draw panel's tools (mockup draw, draw--tools): the four arrows that move players (D-59), then the three marks that
/// explain (D-65). Copy is the mockup's.
enum DrawTool: String, CaseIterable, Sendable, Hashable {
    case run, pass, dribble, press, zone, line, glow

    /// The panel's two rows.
    static let arrows: [DrawTool] = [.run, .pass, .dribble, .press]
    static let marks: [DrawTool] = [.zone, .line, .glow]

    init(_ kind: Arrow.Kind) {
        switch kind {
        case .run: self = .run
        case .pass: self = .pass
        case .dribble: self = .dribble
        case .press: self = .press
        }
    }

    /// The arrow a stroke draws, or nil for a mark tool.
    var arrowKind: Arrow.Kind? {
        switch self {
        case .run: .run
        case .pass: .pass
        case .dribble: .dribble
        case .press: .press
        case .zone, .line, .glow: nil
        }
    }

    var drawsMarks: Bool { arrowKind == nil }

    var title: String {
        switch self {
        case .run: "Run"
        case .pass: "Pass"
        case .dribble: "Dribble"
        case .press: "Press"
        case .zone: "Zone"
        case .line: "Line"
        case .glow: "Glow"
        }
    }

    /// What the tool does, under the panel's title (D-59 for arrows; the mockup's HELP for marks).
    var help: String {
        switch self {
        case .run: "Run · solid line · the player follows it"
        case .pass: "Pass · dashed line · the ball follows it"
        case .dribble: "Dribble · wavy line · player and ball follow it"
        case .press: "Press · chevrons · the player closes in"
        case .zone: "Zone · see-through box · drag across the grass"
        case .line: "Line · joins a unit · tap the last player again to finish"
        case .glow: "Glow · rings follow a player · heat stays on the grass"
        }
    }

    /// The handwritten hint over the panel. The line and glow hints are the mockup's; the zone's follows them.
    var hint: String {
        switch self {
        case .run, .pass, .dribble, .press: "Start on a player to draw their \(title.lowercased())."
        case .zone: "Drag across the grass to draw a zone."
        case .line: "Tap players in order to join them."
        case .glow: "Tap a player, or a spot on the grass."
        }
    }
}
