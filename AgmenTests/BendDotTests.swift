import Foundation
import Testing
@testable import Agmen

/// D-72's middle dot on the board: where it sits on any stored arrow (ours, or an older freehand one), what a tap
/// selects, how VoiceOver bends it, what it is called, and removing the arrow.
struct BendDotTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
    private static let full = 105.0 / 68.0

    private static func close(_ a: Point?, _ b: Point, within tolerance: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
    }

    /// A freehand line up the pitch from (0.3, 0.3) whose widest point is a third of the way up, not half way.
    private static func lopsided(count: Int) -> [Point] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return p(0.3 + 0.12 * sin(.pi * pow(t, 0.63)), 0.3 + 0.4 * t)
        }
    }

    // MARK: Where the dot sits

    /// An older freehand arrow isn't one of our curves: its dot is the point furthest from the line joining its ends.
    @Test(arguments: [5, 7, ShapedPath.curveSamples, 40])
    func anOldFreehandArrowsDotIsItsFurthestPointFromTheChord(count: Int) throws {
        let path = Self.lopsided(count: count)
        let furthest = try #require(path.max { abs($0.x - 0.3) < abs($1.x - 0.3) })
        #expect(path.firstIndex(of: furthest) != count / 2, "the fixture's widest point is off the middle sample")
        for aspect in [1, Self.full] {
            #expect(ShapedPath.middle(of: path, aspect: aspect) == furthest, "count \(count), aspect \(aspect)")
        }
    }

    /// Our own curve still reads back its apex, measured either way, even one flattened against a touchline.
    @Test(arguments: [1, 105.0 / 68.0])
    func ourCurveReadsBackItsApex(aspect: Double) throws {
        let stroke = [Self.p(0.2, 0.2), Self.p(0.45, 0.35), Self.p(0.6, 0.7)]
        let path = ShapedPath.path(for: stroke, shape: .curved, aspect: aspect)
        #expect(path.count == ShapedPath.curveSamples)
        #expect(ShapedPath.middle(of: path, aspect: aspect) == path[ShapedPath.curveSamples / 2])
        let edge = ShapedPath.nudged(path, dotTo: Self.p(0.98, 0.45), aspect: aspect)
        #expect(ShapedPath.middle(of: edge, aspect: aspect) == edge[ShapedPath.curveSamples / 2])
    }

    @Test func aLineWithNoBendHasItsDotHalfWay() {
        let collinear = [Self.p(0.2, 0.2), Self.p(0.25, 0.3), Self.p(0.4, 0.6)]
        #expect(Self.close(ShapedPath.middle(of: collinear), Self.p(0.3, 0.4)))
    }

    /// Dragging an old freehand arrow's dot turns it into one clean quadratic through the dot, keeping its ends.
    @Test func nudgingAnOldFreehandArrowMakesACleanCurveThroughTheDot() throws {
        let path = Self.lopsided(count: 9)
        let dot = Self.p(0.4, 0.48)
        let curve = ShapedPath.nudged(path, dotTo: dot, aspect: Self.full)
        #expect(curve.count == ShapedPath.curveSamples)
        #expect(curve.first == path.first && curve.last == path.last)
        #expect(ShapedPath.middle(of: curve, aspect: Self.full) == dot)
        let a = try #require(path.first), b = try #require(path.last)
        let control = Self.p(2 * dot.x - (a.x + b.x) / 2, 2 * dot.y - (a.y + b.y) / 2)
        for (i, point) in curve.enumerated() {
            let t = Double(i) / Double(curve.count - 1), u = 1 - t
            let expected = Self.p(u * u * a.x + 2 * u * t * control.x + t * t * b.x,
                                  u * u * a.y + 2 * u * t * control.y + t * t * b.y)
            #expect(Self.close(point, expected), "sample \(i) is on the one bend")
        }
    }

    /// Through the stroke edit: the arrow and the run that follows it both become the clean curve.
    @Test func bendingAnOldFreehandRunBendsItsRunner() throws {
        var tactic = TestTactics.small()
        let freehand = [Self.p(0.4, 0.2)] + Self.lopsided(count: 9).dropFirst().dropLast().map { Self.p($0.x + 0.1, $0.y - 0.1) }
            + [Self.p(0.4, 0.6)]
        tactic.phases[0].steps[0].arrows = [Arrow(kind: .run, points: freehand)]
        tactic.phases[0].steps[0].runs["h4"] = Path(points: freehand)
        #expect(StrokeEdits.bend(arrow: 0, to: Self.p(0.3, 0.4), step: 0, in: &tactic))
        let step = try TestTactics.step(0, of: tactic)
        #expect(step.arrows[0].points.count == ShapedPath.curveSamples)
        #expect(step.runs["h4"]?.points == step.arrows[0].points)
    }

    // MARK: VoiceOver's bend

    @Test func voiceOverBendsMoreAndLessOnTheSameSide() throws {
        let path = ShapedPath.path(for: [Self.p(0.3, 0.3), Self.p(0.4, 0.5), Self.p(0.3, 0.7)], shape: .curved)
        let deeper = try #require(ShapedPath.dot(of: path, bentBy: 0.02))
        #expect(Self.close(deeper, Self.p(0.42, 0.5)))
        let shallower = try #require(ShapedPath.dot(of: path, bentBy: -0.02))
        #expect(Self.close(shallower, Self.p(0.38, 0.5)))
        let flat = try #require(ShapedPath.dot(of: path, bentBy: -0.5))
        #expect(Self.close(flat, Self.p(0.3, 0.5)), "less than straight is straight, never the other side")
        #expect(ShapedPath.nudged(path, dotTo: flat).count == 2)
        #expect(ShapedPath.dot(of: [], bentBy: 0.02) == nil)
    }

    // MARK: Tapping an arrow

    @Test func aTapNearABentArrowSelectsIt() {
        let straight = Arrow(kind: .pass, points: [Self.p(0.2, 0.2), Self.p(0.6, 0.2)])
        let bent = Arrow(kind: .run, points: ShapedPath.path(for: [Self.p(0.2, 0.3), Self.p(0.4, 0.45), Self.p(0.2, 0.6)],
                                                            shape: .curved))
        let arrows = [bent, straight]
        #expect(ArrowHit.bendable(near: Self.p(0.4, 0.45), in: arrows, aspect: 1, reach: 0.03) == 0)
        #expect(ArrowHit.bendable(near: Self.p(0.3, 0.45), in: arrows, aspect: 1, reach: 0.03) == nil, "inside the bend")
        #expect(ArrowHit.bendable(near: Self.p(0.4, 0.21), in: arrows, aspect: 1, reach: 0.03) == nil,
                "a straight arrow has no dot to drag")
        #expect(ArrowHit.bendable(near: Self.p(0.4, 0.45), in: [bent, bent], aspect: 1, reach: 0.03) == 1, "the top one")
    }

    // MARK: Words

    @Test func theDotAndRowAreNamedAfterTheArrow() throws {
        var tactic = TestTactics.small()
        StrokeEdits.draw([Self.p(0.4, 0.2), Self.p(0.55, 0.35), Self.p(0.4, 0.5)], kind: .run, shape: .curved,
                         from: "h4", step: 0, in: &tactic)
        StrokeEdits.draw([Self.p(0.5, 0.8), Self.p(0.65, 0.65), Self.p(0.6, 0.4)], kind: .press, shape: .curved,
                         from: "a5", step: 0, in: &tactic)
        StrokeEdits.draw([Self.p(0.1, 0.1), Self.p(0.2, 0.2), Self.p(0.1, 0.4)], kind: .dribble, shape: .curved,
                         from: nil, step: 0, in: &tactic)
        let arrows = try TestTactics.step(0, of: tactic).arrows
        #expect(arrows.count == 4)
        #expect(Placement.bendLabel(forArrow: 1, in: tactic, stepIndex: 0) == "Bend of 4's run. Drag to change the curve.")
        #expect(Placement.rowLabel(forArrow: 1, in: tactic, stepIndex: 0) == "4's run · drag the dot to bend")
        #expect(Placement.bendLabel(forArrow: 2, in: tactic, stepIndex: 0) == "Bend of their 5's press. Drag to change the curve.")
        #expect(Placement.bendLabel(forArrow: 3, in: tactic, stepIndex: 0) == "Bend of the dribble. Drag to change the curve.")
        #expect(Placement.rowLabel(forArrow: 3, in: tactic, stepIndex: 0) == "Dribble · drag the dot to bend")
        #expect(Placement.rowLabel(forArrow: 9, in: tactic, stepIndex: 0) == nil)
    }

    // MARK: Removing

    @Test func removeTakesOnlyThatArrowOff() throws {
        var tactic = TestTactics.small()
        StrokeEdits.draw([Self.p(0.1, 0.1), Self.p(0.3, 0.3)], kind: .run, from: nil, step: 0, in: &tactic)
        let before = try TestTactics.step(0, of: tactic)
        #expect(StrokeEdits.removeArrow(at: 0, step: 0, in: &tactic))
        let after = try TestTactics.step(0, of: tactic)
        #expect(after.arrows == Array(before.arrows.dropFirst()))
        #expect(after.runs == before.runs && after.positions == before.positions)
        #expect(!StrokeEdits.removeArrow(at: 5, step: 0, in: &tactic))
        #expect(!StrokeEdits.removeArrow(at: 0, step: 9, in: &tactic))
    }
}
