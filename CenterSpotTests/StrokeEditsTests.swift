import Foundation
import Testing
@testable import CenterSpot

/// D4-2, D-59: what a drawn stroke does to the tactic. The picked kind decides what moves: Run the player, Pass the
/// ball, Dribble both, Press the player; a stroke from the grass is only an arrow. D-28: the mover's next-step
/// position goes to where the stroke ends, adding a step when there is none.
struct StrokeEditsTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// `TestTactics.small()` as a file would open: h4 (0.4, 0.2), h9 (0.5, 0.6) with a run, a5, the ball at h4's feet.
    private static func small() throws -> Tactic {
        try TacticFormat.decode(TacticFormat.encode(TestTactics.small()))
    }

    /// From just off h4 up and inside: a bend the simplifier keeps.
    private static let stroke = [p(0.41, 0.205), p(0.35, 0.3), p(0.3, 0.4), p(0.32, 0.45), p(0.38, 0.5)]
    private static let end = p(0.38, 0.5)

    private func roundTrips(_ tactic: Tactic, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let back = try TacticFormat.decode(TacticFormat.encode(tactic))
        #expect(back == tactic, "the drawn result reopens unchanged", sourceLocation: sourceLocation)
    }

    @Test func aRunMovesThePlayerAlongTheStroke() throws {
        let before = try Self.small()
        var tactic = before
        let outcome = StrokeEdits.draw(Self.stroke, kind: .run, shape: .curved, from: "h4", step: 0, in: &tactic)
        #expect(outcome == .init(changed: true))
        let steps = tactic.phases[0].steps
        let run = try #require(steps.at(0).runs["h4"])
        #expect(run.points.first == Self.p(0.4, 0.2), "anchored at the player")
        #expect(run.points.last == Self.end)
        #expect(run.points.count >= 3, "the bend is kept")
        #expect(steps.at(1).positions["h4"] == Self.end, "D-28: where the stroke ends")
        let arrow = try #require(steps.at(0).arrows.last)
        #expect(arrow.kind == .run && arrow.points == run.points, "the paused board shows the run (D-46)")
        #expect(steps.at(1).positions["ball"] == before.phases[0].steps.at(1).positions["ball"], "the ball stays")
        #expect(steps.at(0).runs["ball"] == nil)
        try roundTrips(tactic)
    }

    /// Long enough as drawn (from the disc's edge), but it ends back by the player's centre: once anchored it goes
    /// nowhere, so it is a tap, not a run (and adds no step).
    @Test func aStrokeBackOntoItsPlayerIsATap() throws {
        let before = try Self.small()
        var tactic = before
        let outcome = StrokeEdits.draw([Self.p(0.43, 0.2), Self.p(0.405, 0.2)], kind: .run, from: "h4", step: 0, in: &tactic)
        #expect(outcome == .init())
        #expect(tactic == before)
    }

    @Test func aPassMovesTheBallNotThePlayer() throws {
        let before = try Self.small()
        var tactic = before
        StrokeEdits.draw(Self.stroke, kind: .pass, from: "h4", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        let ball = try #require(steps.at(0).runs["ball"])
        #expect(ball.points.first == Self.p(0.4, 0.21), "from where the ball is")
        #expect(ball.points.last == Self.end)
        #expect(steps.at(1).positions["ball"] == Self.end)
        #expect(steps.at(0).runs["h4"] == nil)
        #expect(steps.at(1).positions["h4"] == before.phases[0].steps.at(1).positions["h4"], "the passer stays")
        #expect(steps.at(0).arrows.last?.kind == .pass)
        try roundTrips(tactic)
    }

    /// D-59 follow-up (Chime, 7 Nov): the ball only travels when the passer has it at their feet; from anyone else a
    /// Pass is the plan's dashed arrow and the ball stays where it is.
    @Test func aPassFromAPlayerWithoutTheBallIsOnlyTheArrow() throws {
        let before = try Self.small()
        var tactic = before
        let fromNine = [Self.p(0.51, 0.6), Self.p(0.45, 0.7), Self.p(0.4, 0.8)]
        let outcome = StrokeEdits.draw(fromNine, kind: .pass, from: "h9", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(outcome.changed)
        #expect(steps.at(0).arrows.last?.kind == .pass)
        #expect(steps.at(0).runs["ball"] == before.phases[0].steps.at(0).runs["ball"], "the ball doesn't jump")
        #expect(steps.at(1).positions["ball"] == before.phases[0].steps.at(1).positions["ball"])
        #expect(steps.count == before.phases[0].steps.count)
        try roundTrips(tactic)
    }

    /// One rule for who has the ball (`Possession.carrier`): with two players in reach, only the nearer one passes it.
    @Test func onlyTheNearerOfTwoPlayersInReachPassesTheBall() throws {
        var tactic = try Self.small()
        // h9 stands just inside reach of the ball, h4 right on it.
        TacticEdits.moveToken("h9", to: Self.p(0.43, 0.21), step: 0, in: &tactic)
        let before = tactic
        let fromNine = [Self.p(0.43, 0.21), Self.p(0.5, 0.35), Self.p(0.6, 0.5)]
        StrokeEdits.draw(fromNine, kind: .pass, from: "h9", step: 0, in: &tactic)
        #expect(tactic.phases[0].steps.at(1).positions["ball"] == before.phases[0].steps.at(1).positions["ball"],
                "4 has the ball, so 9's pass is only the arrow")
    }

    /// Same for a dribble: without the ball at their feet the player moves alone, and the ball stays.
    @Test func aDribbleWithoutTheBallMovesOnlyThePlayer() throws {
        let before = try Self.small()
        var tactic = before
        let fromNine = [Self.p(0.51, 0.6), Self.p(0.45, 0.7), Self.p(0.4, 0.8)]
        StrokeEdits.draw(fromNine, kind: .dribble, from: "h9", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(steps.at(1).positions["h9"] == Self.p(0.4, 0.8), "the player follows the line")
        #expect(steps.at(0).runs["ball"] == before.phases[0].steps.at(0).runs["ball"], "the ball doesn't jump")
        #expect(steps.at(1).positions["ball"] == before.phases[0].steps.at(1).positions["ball"])
        try roundTrips(tactic)
    }

    /// The engine's "has the ball" matches where the renderer draws the ball at a carrier's feet.
    @Test func possessionReachMatchesTheRenderer() {
        #expect(Possession.reach == Double(BoardGeometry.tokenRadiusRatio) * 1.2)
        #expect(Double(BoardGeometry.carryNone) == 1.2, "a ball out of reach is drawn where it is")
    }

    @Test func aPassWithoutABallIsOnlyTheArrow() throws {
        var tactic = try Self.small()
        TacticEdits.deleteToken("ball", in: &tactic)
        let before = tactic
        let outcome = StrokeEdits.draw(Self.stroke, kind: .pass, from: "h4", step: 0, in: &tactic)
        #expect(outcome.changed)
        #expect(tactic.phases[0].steps.at(0).runs == before.phases[0].steps.at(0).runs)
        #expect(tactic.phases[0].steps.at(1) == before.phases[0].steps.at(1))
        #expect(tactic.phases[0].steps.at(0).arrows.count == before.phases[0].steps.at(0).arrows.count + 1)
    }

    @Test func aDribbleMovesPlayerAndBallTogether() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.stroke, kind: .dribble, from: "h4", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(steps.at(0).runs["h4"]?.points.last == Self.end)
        #expect(steps.at(0).runs["ball"]?.points.last == Self.end)
        #expect(steps.at(0).runs["ball"]?.points.dropFirst() == steps.at(0).runs["h4"]?.points.dropFirst(), "one path")
        #expect(steps.at(1).positions["h4"] == Self.end && steps.at(1).positions["ball"] == Self.end)
        #expect(steps.at(0).arrows.last?.kind == .dribble)
        try roundTrips(tactic)
    }

    @Test func aPressClosesThePlayerIn() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.stroke.map { Self.p($0.x + 0.1, $0.y + 0.6) }, kind: .press, from: "a5", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(steps.at(0).runs["a5"]?.points.first == Self.p(0.5, 0.8))
        #expect(steps.at(1).positions["a5"] == Self.p(Self.end.x + 0.1, 1), "clamped to the pitch")
        #expect(steps.at(0).arrows.last?.kind == .press)
        #expect(steps.at(0).runs["ball"] == nil)
        try roundTrips(tactic)
    }

    @Test(arguments: Arrow.Kind.allCases)
    func aStrokeFromTheGrassIsOnlyAnArrow(kind: Arrow.Kind) throws {
        let before = try Self.small()
        var tactic = before
        let grass = Self.stroke.map { Self.p($0.x + 0.4, $0.y) }
        let outcome = StrokeEdits.draw(grass, kind: kind, from: nil, step: 1, in: &tactic)
        #expect(outcome == .init(changed: true))
        var expected = before
        expected.phases[0].steps[1].arrows = tactic.phases[0].steps.at(1).arrows
        #expect(tactic == expected, "nothing moves")
        #expect(tactic.phases[0].steps.at(1).arrows.map(\.kind) == [kind])
        #expect(tactic.phases[0].steps.at(1).arrows.first?.points.first == grass[0], "the arrow starts where the finger did")
        try roundTrips(tactic)
    }

    @Test(arguments: Arrow.Kind.allCases)
    func drawingOnTheLastStepAddsTheNextStep(kind: Arrow.Kind) throws {
        var tactic = try Self.small()
        // A pass moves the ball only from its carrier: give h4 the ball on the last step first.
        if kind == .pass { TacticEdits.moveToken("ball", to: Self.p(0.4, 0.31), step: 2, in: &tactic) }
        let outcome = StrokeEdits.draw(Self.stroke.map { Self.p($0.x, $0.y + 0.5) }, kind: kind, from: "h4", step: 2, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(outcome == .init(changed: true, addedStep: true))
        #expect(steps.count == 4)
        let mover = kind == .pass ? "ball" : "h4"
        #expect(steps.at(3).positions[mover] == Self.p(0.38, 1))
        #expect(steps.at(2).runs[mover] != nil)
        try roundTrips(tactic)
    }

    @Test func atFortyStepsTheLastStepOnlyGetsTheArrow() throws {
        var tactic = try Self.small()
        while tactic.phases[0].steps.count < Phase.stepCountRange.upperBound {
            TacticEdits.addStep(after: tactic.phases[0].steps.count - 1, in: &tactic)
        }
        let last = tactic.phases[0].steps.count - 1
        let outcome = StrokeEdits.draw(Self.stroke, kind: .run, from: "h4", step: last, in: &tactic)
        #expect(outcome == .init(changed: true, hitStepLimit: true))
        #expect(tactic.phases[0].steps.count == 40)
        #expect(tactic.phases[0].steps.at(last).runs.isEmpty, "the last step has no next step to run to")
        #expect(tactic.phases[0].steps.at(last).arrows.last?.kind == .run)
        try roundTrips(tactic)
    }

    @Test func aStepHoldsAtMostThirtyArrows() throws {
        var tactic = try Self.small()
        tactic.phases[0].steps[1].arrows = Array(repeating: Arrow(kind: .pass, points: [Self.p(0, 0), Self.p(1, 1)]), count: 30)
        let full = tactic
        let grass = StrokeEdits.draw(Self.stroke.map { Self.p($0.x + 0.4, $0.y) }, kind: .run, from: nil, step: 1, in: &tactic)
        #expect(grass == .init(hitArrowLimit: true))
        #expect(tactic == full)
        let player = StrokeEdits.draw(Self.stroke.map { Self.p($0.x, $0.y + 0.05) }, kind: .run, from: "h4", step: 1, in: &tactic)
        #expect(player == .init(changed: true, hitArrowLimit: true), "the player still runs")
        #expect(tactic.phases[0].steps.at(1).arrows.count == 30)
        #expect(tactic.phases[0].steps.at(1).runs["h4"] != nil)
    }

    @Test func aTapIsNotAStroke() throws {
        let before = try Self.small()
        var tactic = before
        #expect(StrokeEdits.draw([Self.p(0.4, 0.2)], kind: .run, from: "h4", step: 0, in: &tactic) == .init())
        #expect(StrokeEdits.draw([Self.p(0.4, 0.2), Self.p(0.405, 0.203)], kind: .pass, from: nil, step: 0, in: &tactic) == .init())
        #expect(StrokeEdits.draw([], kind: .run, from: nil, step: 0, in: &tactic) == .init())
        #expect(StrokeEdits.draw(Self.stroke, kind: .run, from: "h4", step: 7, in: &tactic) == .init(), "no such step")
        #expect(tactic == before)
    }

    @Test func redrawingAPlayersRunReplacesIt() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.stroke, kind: .run, from: "h4", step: 0, in: &tactic)
        let second = [Self.p(0.4, 0.2), Self.p(0.6, 0.3)]
        StrokeEdits.draw(second, kind: .run, from: "h4", step: 0, in: &tactic)
        let step = tactic.phases[0].steps.at(0)
        #expect(step.runs["h4"]?.points == second)
        #expect(step.arrows.filter { $0.kind == .run }.map(\.points) == [second], "one run arrow from 4")
        #expect(step.arrows.contains { $0.kind == .pass }, "the step's pass stays")
    }

    @Test func theNextStepsOwnRunStaysAnchored() throws {
        var tactic = try Self.small()
        StrokeEdits.draw([Self.p(0.4, 0.25), Self.p(0.7, 0.3)], kind: .run, from: "h4", step: 1, in: &tactic)
        StrokeEdits.draw(Self.stroke, kind: .run, from: "h4", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        #expect(steps.at(1).runs["h4"]?.points.first == steps.at(1).positions["h4"])
        #expect(steps.at(1).positions["h4"] == Self.end)
        try roundTrips(tactic)
    }

    @Test func strokesAreClampedAndCapped() throws {
        var tactic = try Self.small()
        let wild = (0..<10_000).map { i in
            Self.p(0.4 + 0.8 * sin(Double(i) / 30), 0.2 + 1.5 * Double(i) / 9_999)
        }
        StrokeEdits.draw(wild, kind: .dribble, from: "h4", step: 0, in: &tactic)
        let step = tactic.phases[0].steps.at(0)
        let paths = [step.runs["h4"]?.points, step.runs["ball"]?.points, step.arrows.last?.points].compactMap { $0 }
        #expect(paths.count == 3)
        for points in paths {
            #expect(Path.pointCountRange.contains(points.count), "\(points.count) points")
            #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
        try roundTrips(tactic)
    }
}

extension Array where Element == Step {
    /// Step `i`, or an empty stand-in and a test issue (never a crash) when an edit left too few steps.
    func at(_ i: Int, sourceLocation: SourceLocation = #_sourceLocation) -> Step {
        guard indices.contains(i) else {
            Issue.record("no step \(i + 1); there are \(count)", sourceLocation: sourceLocation)
            return Step(id: "missing")
        }
        return self[i]
    }
}
