import Foundation
import Testing
@testable import CenterSpot

/// D-72 through the stroke edit: what is stored and what plays is the shaped line, not the finger's wobble, and D-59 /
/// D-62 still decide what moves along it. The file holds ordinary points, so the format doesn't change.
struct StrokeShapeTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// `TestTactics.small()` as a file would open: h4 (0.4, 0.2) with the ball at their feet, h9, a5.
    private static func small() throws -> Tactic {
        try TacticFormat.decode(TacticFormat.encode(TestTactics.small()))
    }

    /// From h4 up the pitch, bowed 0.1 to the right: symmetric, so its deepest point is half way along it.
    private static let bowed: [Point] = (0...30).map { i in
        let t = Double(i) / 30
        return Point(x: 0.4 + 0.1 * sin(.pi * t), y: 0.2 + 0.3 * t)
    }
    private static let end = p(0.4, 0.5)
    private static let apex = p(0.5, 0.35)

    private static func close(_ a: Point?, _ b: Point, within tolerance: Double = 1e-3) -> Bool {
        guard let a else { return false }
        return abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
    }

    private func roundTrips(_ tactic: Tactic, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let data = try TacticFormat.encode(tactic)
        #expect(try TacticFormat.decode(data) == tactic, "reopens unchanged", sourceLocation: sourceLocation)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("shape") && !json.contains("curved"), "no new keys", sourceLocation: sourceLocation)
    }

    @Test func straightIsTheDefault() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, from: "h4", step: 0, in: &tactic)
        let step = tactic.phases[0].steps.at(0)
        #expect(step.runs["h4"]?.points == [Self.p(0.4, 0.2), Self.end])
        #expect(step.arrows.last?.points == [Self.p(0.4, 0.2), Self.end])
        try roundTrips(tactic)
    }

    @Test func aCurvedRunIsOneBendThroughTheDeepestPoint() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, shape: .curved, from: "h4", step: 0, in: &tactic)
        let steps = tactic.phases[0].steps
        let run = try #require(steps.at(0).runs["h4"]).points
        #expect(run.count == ShapedPath.curveSamples)
        #expect(run.first == Self.p(0.4, 0.2) && run.last == Self.end)
        #expect(Self.close(ShapedPath.middle(of: run), Self.apex))
        #expect(steps.at(0).arrows.last?.points == run, "the arrow shows the same line")
        #expect(steps.at(1).positions["h4"] == Self.end)
        try roundTrips(tactic)
    }

    /// The timeline plays the stored line: half way through the move the runner is at the bend's deepest point.
    @Test func theRunnerGoesThroughTheBendAtMidStep() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, shape: .curved, from: "h4", step: 0, in: &tactic)
        let reopened = try TacticFormat.decode(TacticFormat.encode(tactic))
        let mid = Timeline.hold + reopened.phases[0].steps.at(0).duration / 2
        let here = Timeline.state(at: mid, in: reopened).positions["h4"]
        #expect(Self.close(here, Self.apex, within: 2e-3), "at \(String(describing: here))")
    }

    @Test func aCurvedPassCarriesTheBallAlongTheBend() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .pass, shape: .curved, from: "h4", step: 0, in: &tactic)
        let step = tactic.phases[0].steps.at(0)
        let ball = try #require(step.runs["ball"]).points
        let arrow = try #require(step.arrows.last)
        #expect(arrow.kind == .pass && arrow.points.count == ShapedPath.curveSamples)
        #expect(ball.first == Self.p(0.4, 0.21), "from where the ball is")
        #expect(Array(ball.dropFirst()) == Array(arrow.points.dropFirst()), "along the arrow")
        #expect(step.runs["h4"] == nil, "the passer stays")
        try roundTrips(tactic)
    }

    @Test func aCurvedDribbleMovesPlayerAndBallOnOneBend() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .dribble, shape: .curved, from: "h4", step: 0, in: &tactic)
        let step = tactic.phases[0].steps.at(0)
        let player = try #require(step.runs["h4"]).points
        let ball = try #require(step.runs["ball"]).points
        #expect(player.count == ShapedPath.curveSamples)
        #expect(Array(ball.dropFirst()) == Array(player.dropFirst()))
        try roundTrips(tactic)
    }

    @Test func aCurvedPressClosesThePlayerInAlongTheBend() throws {
        var tactic = try Self.small()
        let fromFive = Self.bowed.map { Self.p($0.x + 0.1, $0.y + 0.6) }
        StrokeEdits.draw(fromFive, kind: .press, shape: .curved, from: "a5", step: 0, in: &tactic)
        let run = try #require(tactic.phases[0].steps.at(0).runs["a5"]).points
        #expect(run.first == Self.p(0.5, 0.8))
        #expect(run.count == ShapedPath.curveSamples)
        #expect(run.allSatisfy { (0...1).contains($0.y) }, "clamped to the pitch")
        try roundTrips(tactic)
    }

    /// A loop back to where it started has no direction to bend from: a tap, whichever shape.
    @Test(arguments: ArrowShape.allCases)
    func aLoopBackToTheStartIsATap(shape: ArrowShape) throws {
        let before = try Self.small()
        var tactic = before
        let loop = [Self.p(0.7, 0.3), Self.p(0.85, 0.4), Self.p(0.7, 0.5), Self.p(0.705, 0.305)]
        #expect(StrokeEdits.draw(loop, kind: .run, shape: shape, from: nil, step: 0, in: &tactic) == .init())
        #expect(tactic == before)
    }

    // MARK: Nudging the middle dot

    @Test func bendingAnArrowBendsTheRunsThatFollowIt() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .dribble, shape: .curved, from: "h4", step: 0, in: &tactic)
        let index = tactic.phases[0].steps.at(0).arrows.count - 1
        let h9 = tactic.phases[0].steps.at(0).runs["h9"]
        #expect(StrokeEdits.bend(arrow: index, to: Self.p(0.3, 0.35), step: 0, in: &tactic))
        let step = tactic.phases[0].steps.at(0)
        let arrow = step.arrows[index].points
        #expect(arrow.first == Self.p(0.4, 0.2) && arrow.last == Self.end)
        #expect(Self.close(ShapedPath.middle(of: arrow), Self.p(0.3, 0.35), within: 1e-9), "bent the other way")
        #expect(Array(step.runs["h4"]?.points.dropFirst() ?? []) == Array(arrow.dropFirst()))
        #expect(Array(step.runs["ball"]?.points.dropFirst() ?? []) == Array(arrow.dropFirst()))
        #expect(step.runs["ball"]?.points.first == Self.p(0.4, 0.21), "the ball still starts where it is")
        #expect(step.runs["h9"] == h9, "someone else's run is left alone")
        try roundTrips(tactic)
    }

    /// The runner's next spot was dragged after drawing: the run still follows the arrow's bend and keeps its own end.
    @Test func aRunWhoseEndWasMovedStillBendsWithItsArrow() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, shape: .curved, from: "h4", step: 0, in: &tactic)
        TacticEdits.moveToken("h4", to: Self.p(0.42, 0.52), step: 1, in: &tactic)
        tactic = try TacticFormat.decode(TacticFormat.encode(tactic))  // reopened: the run is anchored to the new spot
        let index = tactic.phases[0].steps.at(0).arrows.count - 1
        #expect(StrokeEdits.bend(arrow: index, to: Self.p(0.3, 0.35), step: 0, in: &tactic))
        let step = tactic.phases[0].steps.at(0)
        let run = try #require(step.runs["h4"]).points
        #expect(run.last == Self.p(0.42, 0.52), "its own end")
        #expect(Array(run.dropFirst().dropLast()) == Array(step.arrows[index].points.dropFirst().dropLast()))
        try roundTrips(tactic)
    }

    @Test func bendingAStraightArrowBendsItsRun() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, from: "h4", step: 0, in: &tactic)
        let nine = Path(points: [Self.p(0.5, 0.6), Self.p(0.55, 0.8)])   // another straight run, ending elsewhere
        tactic.phases[0].steps[0].runs["h9"] = nine
        let index = tactic.phases[0].steps.at(0).arrows.count - 1
        #expect(StrokeEdits.bend(arrow: index, to: Self.p(0.5, 0.35), step: 0, in: &tactic))
        let step = tactic.phases[0].steps.at(0)
        #expect(step.runs["h4"]?.points == step.arrows[index].points)
        #expect(step.runs["h4"]?.points.count == ShapedPath.curveSamples)
        #expect(step.runs["h9"] == nine, "9's straight run doesn't follow 4's arrow")
        try roundTrips(tactic)
    }

    /// Two straight lines that end on the same spot (both clamped into a corner) are still two lines.
    @Test func anotherStraightRunToTheSameSpotIsLeftAlone() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed, kind: .run, from: "h4", step: 0, in: &tactic)
        let nine = Path(points: [Self.p(0.6, 0.3), Self.end])   // 9 also runs to where 4's arrow ends
        tactic.phases[0].steps[0].runs["h9"] = nine
        let index = tactic.phases[0].steps.at(0).arrows.count - 1
        #expect(StrokeEdits.bend(arrow: index, to: Self.p(0.5, 0.35), step: 0, in: &tactic))
        let step = tactic.phases[0].steps.at(0)
        #expect(step.runs["h4"]?.points == step.arrows[index].points, "4 follows their own arrow")
        #expect(step.runs["h9"] == nine, "9 doesn't")
    }

    @Test func bendingAGrassArrowMovesNothingElse() throws {
        var tactic = try Self.small()
        StrokeEdits.draw(Self.bowed.map { Self.p($0.x + 0.3, $0.y) }, kind: .pass, from: nil, step: 1, in: &tactic)
        let before = tactic
        #expect(StrokeEdits.bend(arrow: 0, to: Self.p(0.6, 0.35), step: 1, in: &tactic))
        var expected = before
        expected.phases[0].steps[1].arrows = tactic.phases[0].steps.at(1).arrows
        #expect(tactic == expected)
        #expect(tactic.phases[0].steps.at(1).arrows[0].points.count == ShapedPath.curveSamples)
        #expect(!StrokeEdits.bend(arrow: 5, to: Self.p(0.6, 0.35), step: 1, in: &tactic), "no such arrow")
        #expect(!StrokeEdits.bend(arrow: 0, to: Self.p(0.6, 0.35), step: 9, in: &tactic), "no such step")
    }
}
