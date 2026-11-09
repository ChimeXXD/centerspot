import Foundation
import Testing
@testable import CenterSpot

/// D-72: a drawn arrow takes a shape instead of the finger's wobble. Straight joins the stroke's ends; Curved is one
/// quadratic bend through the stroke's deepest point, with a middle dot to nudge it. Stored as ordinary points.
struct ShapedPathTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// A stroke up the pitch from (x, y0) to (x, y0 + rise) that bows sideways by `depth` (negative: to the left).
    private static func bow(x: Double = 0.3, y0: Double = 0.3, rise: Double = 0.4, depth: Double, count: Int = 31) -> [Point] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return p(x + depth * sin(.pi * t), y0 + rise * t)
        }
    }

    /// How far each point is from the vertical line x = `x` (signed: right is positive).
    private static func sideways(_ points: [Point], from x: Double) -> [Double] { points.map { $0.x - x } }

    @Test func straightIsTheStrokesTwoEnds() {
        let stroke = Self.bow(depth: 0.12)
        let path = ShapedPath.path(for: stroke, shape: .straight)
        #expect(path == [stroke[0], stroke[stroke.count - 1]])
    }

    @Test(arguments: [0.1, -0.1])
    func curvedBendsToTheSideItWasDrawnAsDeepAsTheStroke(depth: Double) throws {
        let stroke = Self.bow(depth: depth)
        let path = ShapedPath.path(for: stroke, shape: .curved, aspect: 105.0 / 68.0)
        #expect(path.count == ShapedPath.curveSamples)
        #expect(path.first == stroke.first && path.last == stroke.last, "the ends are where the finger started and stopped")
        let off = Self.sideways(path, from: 0.3)
        #expect(off.allSatisfy { $0 * depth >= -1e-12 }, "every point on the side the stroke bowed to")
        let deepest = try #require(off.map(abs).max())
        #expect(abs(deepest - abs(depth)) < 0.002, "depth \(deepest), drawn \(abs(depth))")
        let dot = try #require(ShapedPath.middle(of: path))
        #expect(abs(dot.x - (0.3 + depth)) < 1e-9 && abs(dot.y - 0.5) < 1e-9, "the middle dot sits on the deepest point")
        // Every sample is on the one quadratic: with a vertical chord its sideways offset is 4t(1 − t) × depth.
        for (i, o) in off.enumerated() {
            let t = Double(i) / Double(path.count - 1)
            #expect(abs(o - 4 * t * (1 - t) * depth) < 1e-9, "sample \(i) is off the curve")
        }
    }

    /// The bend's deepest point stays where the stroke's was, but no nearer an end than a quarter of the way, so the
    /// curve never hooks back past an end.
    @Test(arguments: [1, 105.0 / 68.0])
    func anOffCentreBendKeepsItsPlaceWithoutHooking(aspect: Double) throws {
        let early = [Self.p(0.3, 0.3), Self.p(0.4, 0.4), Self.p(0.3, 0.7)]   // deepest a quarter of the way up
        let dot = try #require(ShapedPath.middle(of: ShapedPath.path(for: early, shape: .curved, aspect: aspect)))
        #expect(abs(dot.y - 0.4) < 1e-9 && abs(dot.x - 0.4) < 1e-9)
        let late = [Self.p(0.3, 0.3), Self.p(0.4, 0.69), Self.p(0.3, 0.7)]   // nearly at the end
        let path = ShapedPath.path(for: late, shape: .curved, aspect: aspect)
        let lateDot = try #require(ShapedPath.middle(of: path))
        #expect(abs(lateDot.y - 0.6) < 1e-9, "held three quarters of the way up, got \(lateDot.y)")
        let ys = path.map(\.y)
        #expect(zip(ys, ys.dropFirst()).allSatisfy { $0 <= $1 + 1e-12 }, "always moving up the chord")
    }

    /// A finger's wobble on a meant-straight line bows a few per cent of its length: under 8 % it is straight.
    @Test func aNearlyStraightCurvedStrokeComesOutStraight() {
        let wobble = Self.bow(depth: 0.025)   // 6 % of a 0.4 chord
        #expect(ShapedPath.path(for: wobble, shape: .curved) == [wobble[0], wobble[wobble.count - 1]])
        let meant = Self.bow(depth: 0.04)     // 10 %
        #expect(ShapedPath.path(for: meant, shape: .curved).count == ShapedPath.curveSamples)
        let short = Self.bow(rise: 0.05, depth: 0.008)   // 16 %, but under the 0.01 floor of finger jitter
        #expect(ShapedPath.path(for: short, shape: .curved).count == 2)
    }

    /// "Under 8 %" is measured as the pitch looks: the same bow up a long full pitch is a smaller share of the chord.
    @Test func straightnessIsJudgedAsThePitchLooks() {
        let stroke = Self.bow(depth: 0.035)   // 8.75 % of 0.4 in pitch units; 5.7 % of the chord on a full pitch
        #expect(ShapedPath.path(for: stroke, shape: .curved, aspect: 1).count == ShapedPath.curveSamples)
        #expect(ShapedPath.path(for: stroke, shape: .curved, aspect: 105.0 / 68.0).count == 2)
    }

    @Test(arguments: ArrowShape.allCases)
    func everyPointStaysOnThePitch(shape: ArrowShape) {
        // From off the pitch, bowed into the bottom-right corner: the fitted bend runs past the goal line.
        let stroke = [Self.p(0.6, -0.1), Self.p(1.0, 0.0), Self.p(1.3, 0.4)]
        let path = ShapedPath.path(for: stroke, shape: shape)
        #expect(path.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        #expect(path.first == Self.p(0.6, 0) && path.last == Self.p(1, 0.4))
        if shape == .curved {
            #expect(path.count == ShapedPath.curveSamples)
            #expect(path.filter { $0.y == 0 }.count > 2, "the bend is flattened along the goal line, not dropped")
        }
    }

    @Test func aHugeStrokeStaysWellUnderTheCap() {
        let wild = (0..<10_000).map { i in Self.p(0.5 + 0.4 * sin(Double(i) / 30), Double(i) / 9_999) }
        for shape in ArrowShape.allCases {
            let count = ShapedPath.path(for: wild, shape: shape).count
            #expect(count <= ShapedPath.curveSamples && count < Path.pointCountRange.upperBound / 4)
        }
        #expect(ShapedPath.curveSamples % 2 == 1, "an odd count puts a sample on the middle dot")
    }

    @Test func degenerateStrokes() {
        #expect(ShapedPath.path(for: [], shape: .curved).isEmpty)
        #expect(ShapedPath.path(for: [Self.p(0.2, 0.2)], shape: .curved) == [Self.p(0.2, 0.2), Self.p(0.2, 0.2)])
        let loop = [Self.p(0.2, 0.2), Self.p(0.4, 0.4), Self.p(0.2, 0.2)]
        #expect(ShapedPath.path(for: loop, shape: .curved) == [Self.p(0.2, 0.2), Self.p(0.2, 0.2)], "no chord, no side")
    }

    // MARK: The middle dot

    @Test func theMiddleDotOfAStraightPathIsHalfway() {
        let half = ShapedPath.middle(of: [Self.p(0.2, 0.2), Self.p(0.4, 0.6)])
        #expect(half.map { abs($0.x - 0.3) < 1e-9 && abs($0.y - 0.4) < 1e-9 } == true)
        #expect(ShapedPath.middle(of: []) == nil)
        // Not one of ours (an older freehand line): the point furthest from the line joining its ends (D-72 review).
        let freehand = [Self.p(0.2, 0.2), Self.p(0.1, 0.35), Self.p(0.25, 0.5), Self.p(0.2, 0.6)]
        #expect(ShapedPath.middle(of: freehand) == Self.p(0.1, 0.35))
    }

    @Test func nudgingMovesTheBendAndKeepsTheEnds() throws {
        let path = ShapedPath.path(for: Self.bow(depth: 0.1), shape: .curved)
        let deeper = ShapedPath.nudged(path, dotTo: Self.p(0.45, 0.5))
        #expect(deeper.count == ShapedPath.curveSamples)
        #expect(deeper.first == path.first && deeper.last == path.last)
        let dot = try #require(ShapedPath.middle(of: deeper))
        #expect(abs(dot.x - 0.45) < 1e-9 && abs(dot.y - 0.5) < 1e-9)
        #expect(abs((Self.sideways(deeper, from: 0.3).max() ?? 0) - 0.15) < 1e-9, "as deep as the dot")

        let flipped = ShapedPath.nudged(path, dotTo: Self.p(0.2, 0.5))
        #expect(Self.sideways(flipped, from: 0.3).allSatisfy { $0 <= 1e-12 }, "dragged across, it bends the other way")

        let straight = ShapedPath.nudged(path, dotTo: Self.p(0.305, 0.5))
        #expect(straight == [path[0], path[path.count - 1]], "dropped on the line, it straightens")

        let bent = ShapedPath.nudged(straight, dotTo: Self.p(0.4, 0.5))
        #expect(bent.count == ShapedPath.curveSamples, "a straight arrow's dot bends it")
    }

    @Test func aNudgedDotStaysOnThePitchAndBetweenTheQuarters() throws {
        let path = ShapedPath.path(for: Self.bow(depth: 0.1), shape: .curved)
        let dot = try #require(ShapedPath.middle(of: ShapedPath.nudged(path, dotTo: Self.p(1.4, 0.95))))
        #expect(abs(dot.x - 1) < 1e-9, "held on the touchline")
        #expect(abs(dot.y - 0.6) < 1e-9, "held three quarters of the way along")
        let nudged = ShapedPath.nudged(path, dotTo: Self.p(1.4, 0.95))
        #expect(nudged.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }
}
