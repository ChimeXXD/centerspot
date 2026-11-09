import Testing
@testable import CenterSpot

/// The bent arrow selected in Draw is kept by what it is, not where it sits in the step's list, so an undo that adds or
/// removes another arrow never moves the selection onto it (fix-everything, 8 Nov).
struct ArrowSelectionTests {
    private let a = Arrow(kind: .run, points: [Point(x: 0.1, y: 0.1), Point(x: 0.2, y: 0.3), Point(x: 0.3, y: 0.5)])
    private let b = Arrow(kind: .pass, points: [Point(x: 0.6, y: 0.2), Point(x: 0.7, y: 0.4), Point(x: 0.8, y: 0.6)])

    @Test func followsTheArrowWhenAnEarlierOneGoes() {
        let selected = ArrowEditing.Selected(step: 2, arrow: b)
        #expect(selected.index(in: [a, b]) == 1)
        // An undo takes `a` away: the selection stays on `b`, now first.
        #expect(selected.index(in: [b]) == 0)
    }

    /// An undo that changes the selected arrow itself (its bend) drops the selection instead of picking another.
    @Test func dropsWhenTheArrowItselfChanges() {
        let selected = ArrowEditing.Selected(step: 2, arrow: b)
        var unbent = b
        unbent.points = [b.points[0], b.points[2]]
        #expect(selected.index(in: [a, unbent]) == nil)
    }
}
