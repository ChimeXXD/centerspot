import SwiftUI

/// How the board screen arranges the pitch and its controls (D-73). Chosen from the size class and the space the
/// screen has, never the device model, so an iPad in Split View with a narrow window gets the iPhone layout.
enum BoardLayout: Equatable {
    /// iPhone, and any compact-width window: pitch, the row under it, the steps strip, the toolbar.
    case compact
    /// Regular width, taller than wide: the pitch as big as the height allows, centred, with one row under it
    /// (steps on the left, the selection on the right).
    case regularPortrait
    /// Regular width, wider than tall: the upright pitch fills the height on the left; the nav row, every step
    /// (D-75), the selection and the draw tools sit in a column on the right.
    case regularLandscape

    /// The narrowest right column that still fits the step list and the four arrow tiles.
    static let minimumColumn: CGFloat = 360

    init(sizeClass: UserInterfaceSizeClass?, size: CGSize) {
        guard sizeClass == .regular, size.width > 0, size.height > 0 else {
            self = .compact
            return
        }
        self = size.width > size.height ? .regularLandscape : .regularPortrait
    }
}
