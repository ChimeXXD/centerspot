import Foundation
import Testing
@testable import Agmen

/// D-08, SPEC §9 Editing: a drawn stroke becomes at most 200 points (Douglas–Peucker, then capped), keeping its ends.
struct PathSimplifierTests {
    private static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// A wobbly line up the left wing, `count` samples, with a sideways jitter smaller than the tolerance.
    private static func wobblyLine(_ count: Int, jitter: Double = 0.001) -> [Point] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return p(0.15 + (i.isMultiple(of: 2) ? jitter : -jitter), 0.2 + 0.5 * t)
        }
    }

    @Test func aNearlyStraightStrokeBecomesItsTwoEnds() {
        let stroke = Self.wobblyLine(300)
        let simple = PathSimplifier.simplify(stroke)
        #expect(simple == [stroke[0], stroke[299]])
    }

    @Test func aCornerIsKept() {
        // Up the wing, then a sharp cut inside: an L of 101 samples.
        let up = (0..<50).map { Self.p(0.1, 0.2 + 0.4 * Double($0) / 50) }
        let corner = Self.p(0.1, 0.6)
        let across = (1...50).map { Self.p(0.1 + 0.3 * Double($0) / 50, 0.6) }
        let stroke = up + [corner] + across
        #expect(PathSimplifier.simplify(stroke) == [stroke[0], corner, stroke[stroke.count - 1]])
    }

    @Test func endpointsAreAlwaysKept() {
        let circle = (0...400).map { i -> Point in
            let a = Double(i) / 400 * 2 * .pi * 0.9
            return Self.p(0.5 + 0.3 * cos(a), 0.5 + 0.3 * sin(a))
        }
        let simple = PathSimplifier.simplify(circle)
        #expect(simple.first == circle.first && simple.last == circle.last)
        #expect(simple.count > 4, "a curve keeps its shape")
    }

    @Test func tenThousandNoisyPointsAreCappedAt200() {
        // A zigzag far rougher than the tolerance, so Douglas–Peucker alone keeps nearly every point.
        let stroke = (0..<10_000).map { i in
            Self.p(0.5 + (i.isMultiple(of: 2) ? 0.05 : -0.05), Double(i) / 9_999)
        }
        let simple = PathSimplifier.simplify(stroke)
        #expect(simple.count <= 200 && simple.count >= 2, "\(simple.count) points")
        #expect(simple.first == stroke.first && simple.last == stroke.last)
    }

    /// It runs on the main thread when a stroke ends. Unbounded Douglas–Peucker took about 64 s on this stroke in a
    /// Debug build; the input bound keeps it to milliseconds. 2 s is far above that, so this only fails on a regression.
    @Test func aHugeScribbleIsQuick() {
        let scribble = (0..<10_000).map { i in Self.p(0.5 + (i.isMultiple(of: 2) ? 0.05 : -0.05), Double(i) / 9_999) }
        let elapsed = ContinuousClock().measure { _ = PathSimplifier.simplify(scribble, aspect: 105.0 / 68) }
        #expect(elapsed < .seconds(2), "\(elapsed)")
    }

    @Test func aCapBelowTheDefaultIsRespected() {
        let stroke = (0..<500).map { i in Self.p(Double(i % 7) / 7, Double(i) / 499) }
        let simple = PathSimplifier.simplify(stroke, maxPoints: 12)
        #expect(simple.count <= 12 && simple.count >= 2)
        #expect(simple.first == stroke.first && simple.last == stroke.last)
    }

    @Test func onePointBecomesTwo() {
        #expect(PathSimplifier.simplify([Self.p(0.3, 0.4)]) == [Self.p(0.3, 0.4), Self.p(0.3, 0.4)])
    }

    @Test func zeroLengthKeepsTwoPoints() {
        let still = Array(repeating: Self.p(0.6, 0.6), count: 50)
        #expect(PathSimplifier.simplify(still) == [Self.p(0.6, 0.6), Self.p(0.6, 0.6)])
    }

    @Test func noPointsStayNoPoints() {
        #expect(PathSimplifier.simplify([]).isEmpty)
    }

    @Test func aLoopBackToTheStartKeepsItsFarPoint() {
        // Out and back to where it began: the first and last points coincide.
        let stroke = [Self.p(0.2, 0.2), Self.p(0.3, 0.4), Self.p(0.4, 0.6), Self.p(0.3, 0.4), Self.p(0.2, 0.2)]
        let simple = PathSimplifier.simplify(stroke)
        #expect(simple.contains(Self.p(0.4, 0.6)))
        #expect(simple.first == stroke.first && simple.last == stroke.last)
    }

    @Test func distanceIsMeasuredOnThePitchNotInRawUnits() {
        // 0.0035 up a full pitch is 0.0054 pitch widths, above the 0.004 tolerance; across it is 0.0035, below. The
        // bump survives only when the pitch's aspect is applied.
        let stroke = [Self.p(0.1, 0.5), Self.p(0.3, 0.5035), Self.p(0.5, 0.5)]
        #expect(PathSimplifier.simplify(stroke, aspect: 105.0 / 68).count == 3)
        #expect(PathSimplifier.simplify(stroke, aspect: 1).count == 2)
    }
}
