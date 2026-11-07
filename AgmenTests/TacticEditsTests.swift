import Foundation
import Testing
@testable import Agmen

/// Step edits on the board (SPEC §6, §9 Editing): every edit is a pure function on `inout Tactic`.
struct TacticEditsTests {
    private func steps(_ t: Tactic) -> [Step] { t.phases[0].steps }

    @Test func moveTokenSetsThePositionInThatStepOnly() {
        var t = TestTactics.small()
        TacticEdits.moveToken("h4", to: Point(x: 0.7, y: 0.4), step: 1, in: &t)
        #expect(steps(t)[1].positions["h4"] == Point(x: 0.7, y: 0.4))
        #expect(steps(t)[0].positions["h4"] == Point(x: 0.4, y: 0.2))
        #expect(steps(t)[2].positions["h4"] == Point(x: 0.4, y: 0.3))
    }

    @Test(arguments: [(-0.2, 0.5, 0.0, 0.5), (1.4, 0.5, 1.0, 0.5), (0.5, -3.0, 0.5, 0.0), (0.5, 9.0, 0.5, 1.0), (-1, 2, 0, 1)])
    func moveTokenClampsToThePitch(x: Double, y: Double, cx: Double, cy: Double) {
        var t = TestTactics.small()
        TacticEdits.moveToken("h9", to: Point(x: x, y: y), step: 0, in: &t)
        #expect(steps(t)[0].positions["h9"] == Point(x: cx, y: cy))
    }

    @Test func moveTokenIgnoresUnknownTokensAndSteps() {
        var t = TestTactics.small()
        let before = t
        TacticEdits.moveToken("nobody", to: .centre, step: 0, in: &t)
        TacticEdits.moveToken("h4", to: .centre, step: 9, in: &t)
        #expect(t == before)
    }

    @Test func addStepInsertsACopyAfterTheCurrentOneWithANewID() throws {
        var t = TestTactics.small()
        let index = try #require(TacticEdits.addStep(after: 0, in: &t))
        #expect(index == 1)
        #expect(steps(t).count == 4)
        let copy = steps(t)[1]
        #expect(copy.positions == steps(t)[0].positions)
        #expect(copy.duration == steps(t)[0].duration)
        #expect(Set(steps(t).map(\.id)).count == 4)
        // The copy takes the original's runs, so the move to the old next step is kept; arrows and note stay.
        #expect(copy.runs["h9"] != nil && steps(t)[0].runs.isEmpty)
        #expect(copy.arrows.isEmpty && copy.note == nil)
        #expect(steps(t)[0].note == "Ball over the top")
    }

    @Test func addStepFillsCarriedPositionsSoTheCopyIsComplete() throws {
        var t = TestTactics.small()
        t.phases[0].steps[2].positions["a5"] = nil
        let index = try #require(TacticEdits.addStep(after: 2, in: &t))
        #expect(steps(t)[index].positions["a5"] == Point(x: 0.52, y: 0.78))
    }

    @Test func addStepStopsAtFortySteps() {
        var t = TestTactics.small()
        while steps(t).count < Phase.stepCountRange.upperBound { _ = TacticEdits.addStep(after: steps(t).count - 1, in: &t) }
        #expect(steps(t).count == 40)
        #expect(TacticEdits.addStep(after: 0, in: &t) == nil)
        #expect(steps(t).count == 40)
    }

    @Test func deleteStepRemovesItButNeverTheLastOne() {
        var t = TestTactics.small()
        #expect(TacticEdits.deleteStep(at: 1, in: &t))
        #expect(steps(t).map(\.id) == ["s1", "s3"])
        #expect(TacticEdits.deleteStep(at: 0, in: &t))
        #expect(!TacticEdits.deleteStep(at: 0, in: &t))
        #expect(steps(t).map(\.id) == ["s3"])
        #expect(!TacticEdits.deleteStep(at: 5, in: &t))
    }

    @Test func runsOnTheNewLastStepAreDropped() {
        var t = TestTactics.small()
        _ = TacticEdits.deleteStep(at: 2, in: &t)
        _ = TacticEdits.deleteStep(at: 1, in: &t)
        #expect(steps(t).count == 1 && steps(t)[0].runs.isEmpty)
    }

    @Test(arguments: [(0, 2, ["s2", "s3", "s1"]), (2, 0, ["s3", "s1", "s2"]), (1, 1, ["s1", "s2", "s3"]), (0, 9, ["s1", "s2", "s3"])])
    func moveStepReorders(from: Int, to: Int, expected: [String]) {
        var t = TestTactics.small()
        TacticEdits.moveStep(from: from, to: to, in: &t)
        #expect(steps(t).map(\.id) == expected)
        #expect(steps(t).last?.runs.isEmpty == true)
    }

    @Test(arguments: [(0.1, 0.3), (0.3, 0.3), (2.5, 2.5), (5.0, 5.0), (12, 5.0), (Double.nan, 1.2)])
    func durationIsClamped(input: Double, expected: Double) {
        var t = TestTactics.small()
        TacticEdits.setDuration(input, step: 1, in: &t)
        #expect(steps(t)[1].duration == expected)
    }

    @Test func noteIsTruncatedAndAnEmptyNoteIsRemoved() {
        var t = TestTactics.small()
        TacticEdits.setNote(String(repeating: "a", count: 200), step: 1, in: &t)
        #expect(steps(t)[1].note?.count == 140)
        TacticEdits.setNote("  ", step: 1, in: &t)
        #expect(steps(t)[1].note == nil)
        TacticEdits.setNote(" Overlap ", step: 1, in: &t)
        #expect(steps(t)[1].note == "Overlap")
    }

    @Test func setPitchChangesKindAndStyle() {
        var t = TestTactics.small()
        TacticEdits.setPitch(kind: .fiveASide, style: .stripes, in: &t)
        #expect(t.pitch == Pitch(kind: .fiveASide, style: .stripes))
    }
}
