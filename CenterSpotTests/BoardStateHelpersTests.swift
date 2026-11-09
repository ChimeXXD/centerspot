import Foundation
import Testing
@testable import CenterSpot

/// The still board shown while editing a step, and the formation tag under the pitch.
struct BoardStateHelpersTests {
    @Test func restingStateMatchesTheTimelineAtTheEndOfEachHold() throws {
        let hero = try Fixtures.tactic("overlap-left")
        var start = 0.0
        for (i, step) in hero.phases[0].steps.enumerated() {
            let resting = Timeline.restingState(step: i, in: hero)
            let timed = Timeline.state(at: start + Timeline.hold, in: hero)
            #expect(resting.stepIndex == i)
            #expect(resting.positions == timed.positions)
            #expect(resting.arrows.map(\.arrow) == step.arrows)
            #expect(resting.arrows.allSatisfy { $0.opacity == 1 })
            start = start + Timeline.hold + step.duration  // the same order of additions as Timeline
        }
    }

    @Test func restingStateCarriesMissingPositionsForward() {
        var t = TestTactics.small()
        t.phases[0].steps[2].positions["a5"] = nil
        #expect(Timeline.restingState(step: 2, in: t).positions["a5"] == Point(x: 0.52, y: 0.78))
        #expect(Timeline.restingState(step: 7, in: t).positions.isEmpty)
    }

    @Test func formationTagNamesTheShapeOfStepOne() throws {
        let hero = try Fixtures.tactic("overlap-left"), presets = try Presets.bundled()
        #expect(FormationMatch.formation(of: hero, in: presets.formations)?.id == "4-3-3")
        #expect(FormationMatch.formation(of: TacticDocument.blank(), in: presets.formations) == nil)
    }

    @Test func formationTagFollowsTheStepOnScreen() throws {
        let hero = try Fixtures.tactic("overlap-left"), presets = try Presets.bundled()
        let shape = try #require(presets.formation("4-4-2"))
        let changed = shape.apply(to: hero, stepIndex: 2)
        #expect(FormationMatch.formation(of: changed, in: presets.formations, step: 2)?.id == "4-4-2")
        #expect(FormationMatch.formation(of: changed, in: presets.formations, step: 0)?.id == "4-3-3")
    }

    @Test func eachPresetIsRecognisedAfterItIsApplied() throws {
        let presets = try Presets.bundled()
        for formation in presets.formations {
            let applied = formation.apply(to: TacticDocument.blank(), stepIndex: 0)
            #expect(FormationMatch.formation(of: applied, in: presets.formations)?.id == formation.id)
        }
    }

    @Test func aPlayerOutOfShapeLosesTheTag() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let presets = try Presets.bundled()
        TacticEdits.moveToken("h9", to: Point(x: 0.9, y: 0.95), step: 0, in: &hero)
        #expect(FormationMatch.formation(of: hero, in: presets.formations) == nil)
    }
}
