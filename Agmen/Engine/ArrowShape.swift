import Foundation

/// The shape a drawn arrow takes (D-72), picked on the Draw panel: Straight (the default) joins where the stroke
/// starts and ends; Curved is one smooth bend fitted to it. Not stored: the file holds the resulting points.
enum ArrowShape: String, CaseIterable, Sendable {
    case straight, curved
}
