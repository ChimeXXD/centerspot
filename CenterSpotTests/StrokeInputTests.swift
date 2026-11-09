import Testing
@testable import CenterSpot

/// D-90: the Pencil draws only after Draw is picked; outside draw mode it taps and drags players like a finger.
struct StrokeInputTests {
    @Test func iPadPencilDrawsOnlyInDrawMode() {
        #expect(StrokeInput.board(.editing, pencilDraws: true) == .none)
        #expect(StrokeInput.board(.playing, pencilDraws: true) == .none)
        #expect(StrokeInput.board(.drawing, pencilDraws: true) == .pencil)
    }

    @Test func iPhoneDrawModeTakesTheFingerToo() {
        #expect(StrokeInput.board(.editing, pencilDraws: false) == .none)
        #expect(StrokeInput.board(.playing, pencilDraws: false) == .none)
        #expect(StrokeInput.board(.drawing, pencilDraws: false) == .fingerAndPencil)
    }
}
