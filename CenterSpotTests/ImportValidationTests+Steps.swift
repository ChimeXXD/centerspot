import Foundation
import Testing
@testable import CenterSpot

/// FORMAT.md Rules rows for `steps`, `runs` and `arrows` that refuse the file.
extension ImportValidationTests {
    private func tactic(withStepCount count: Int) -> Tactic {
        var tactic = T.small()
        tactic.phases[0].steps = (0..<count).map { Step(id: "s\($0 + 1)") }
        return tactic
    }

    @Test func noStepsAreRefused() throws {
        #expect(T.refusal(try T.data(tactic(withStepCount: 0))) == .unreadable)
    }

    @Test func fortyOneStepsAreRefused() throws {
        #expect(T.refusal(try T.data(tactic(withStepCount: 41))) == .unreadable)
        #expect(T.refusal(try T.data(tactic(withStepCount: 40))) == nil)
    }

    @Test func duplicateStepIDIsRefused() throws {
        var tactic = T.small()
        tactic.phases[0].steps[2].id = "s1"
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    // MARK: runs

    private func tactic(withRunOf count: Int, onStep index: Int = 0) -> Tactic {
        var tactic = T.small()
        let points = (0..<count).map { T.p(0.5, Double($0) / Double(max(count, 1))) }
        tactic.phases[0].steps[index].runs = ["h9": Path(points: points)]
        return tactic
    }

    @Test func runWithOnePointIsRefused() throws {
        #expect(T.refusal(try T.data(tactic(withRunOf: 1))) == .unreadable)
        #expect(T.refusal(try T.data(tactic(withRunOf: 0))) == .unreadable)
    }

    @Test func runWithTwoHundredAndOnePointsIsRefused() throws {
        #expect(T.refusal(try T.data(tactic(withRunOf: 201))) == .unreadable)
        #expect(T.refusal(try T.data(tactic(withRunOf: 200))) == nil)
        #expect(T.refusal(try T.data(tactic(withRunOf: 2))) == nil)
    }

    /// Judgement call: point limits are structural, so they refuse even a run that would then be dropped.
    @Test func oversizedRunOnLastStepIsStillRefused() throws {
        #expect(T.refusal(try T.data(tactic(withRunOf: 201, onStep: 2))) == .unreadable)
    }

    // MARK: arrows

    @Test func thirtyOneArrowsAreRefused() throws {
        var tactic = T.small()
        let arrow = Arrow(kind: .press, points: [T.p(0.1, 0.1), T.p(0.2, 0.2)])
        tactic.phases[0].steps[1].arrows = Array(repeating: arrow, count: 31)
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
        tactic.phases[0].steps[1].arrows = Array(repeating: arrow, count: 30)
        #expect(T.refusal(try T.data(tactic)) == nil)
    }

    @Test(arguments: [0, 1, 201])
    func arrowWithWrongPointCountIsRefused(count: Int) throws {
        var tactic = T.small()
        let points = (0..<count).map { T.p(0.3, Double($0) / 201) }
        tactic.phases[0].steps[0].arrows = [Arrow(kind: .run, points: points)]
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func arrowWithTwoHundredPointsOpens() throws {
        var tactic = T.small()
        let points = (0..<200).map { T.p(0.3, Double($0) / 200) }
        tactic.phases[0].steps[0].arrows = [Arrow(kind: .dribble, points: points)]
        #expect(T.refusal(try T.data(tactic)) == nil)
    }

    @Test func unknownArrowKindIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"kind\":\"pass\"", with: "\"kind\":\"lob\"")
        #expect(T.refusal(data) == .unreadable)
    }
}
