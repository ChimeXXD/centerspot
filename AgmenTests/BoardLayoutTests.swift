import CoreGraphics
import SwiftUI
import Testing
@testable import Agmen

/// D-73: the board picks its layout from the size class and the window's shape, never the device model, so a narrow
/// Split View window on iPad gets the iPhone layout, and the steps list reads in football words (D-75).
struct BoardLayoutTests {
    @Test func compactWidthIsTheIPhoneLayout() {
        #expect(BoardLayout(sizeClass: .compact, size: CGSize(width: 440, height: 956)) == .compact)
        #expect(BoardLayout(sizeClass: .compact, size: CGSize(width: 1376, height: 1032)) == .compact)
        #expect(BoardLayout(sizeClass: nil, size: CGSize(width: 1376, height: 1032)) == .compact)
    }

    @Test func regularWidthFollowsTheWindowsShape() {
        #expect(BoardLayout(sizeClass: .regular, size: CGSize(width: 1376, height: 1032)) == .regularLandscape)
        #expect(BoardLayout(sizeClass: .regular, size: CGSize(width: 1032, height: 1376)) == .regularPortrait)
        // Two-thirds of a landscape iPad: taller than wide, so the pitch goes on top.
        #expect(BoardLayout(sizeClass: .regular, size: CGSize(width: 900, height: 1032)) == .regularPortrait)
    }

    @Test func notMeasuredYetIsCompact() {
        #expect(BoardLayout(sizeClass: .regular, size: .zero) == .compact)
    }

    @Test @MainActor func stepRowsReadTheirNumberTimeAndNote() {
        let step = Step(id: "s2", duration: 1.4, note: "11 drives inside")
        #expect(StepsList.label(index: 1, count: 5, step: step) == "Step 2 of 5, 1.4 seconds, 11 drives inside")
        let plain = Step(id: "s1", duration: 1)
        #expect(StepsList.label(index: 0, count: 1, step: plain) == "Step 1 of 1, 1 second")
    }
}
