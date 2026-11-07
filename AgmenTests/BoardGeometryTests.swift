import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// Normalised points ↔ board points, the aspect fit and hit-testing (D-05, SPEC §4, §6).
struct BoardGeometryTests {
    @Test(arguments: Pitch.Kind.allCases)
    func pointsRoundTrip(kind: Pitch.Kind) {
        let g = BoardGeometry(kind: kind, fitting: CGRect(x: 12, y: 30, width: 354, height: 600))
        for p in [Point(x: 0, y: 0), Point(x: 1, y: 1), Point(x: 0.37, y: 0.81), .centre] {
            let back = g.normalised(g.point(p))
            #expect(abs(back.x - p.x) < 1e-9 && abs(back.y - p.y) < 1e-9)
        }
    }

    @Test func attackingUpward() {
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 340, height: 800))
        #expect(g.point(Point(x: 0, y: 1)) == CGPoint(x: g.pitchRect.minX, y: g.pitchRect.minY))
        #expect(g.point(Point(x: 1, y: 0)) == CGPoint(x: g.pitchRect.maxX, y: g.pitchRect.maxY))
    }

    @Test(arguments: [(Pitch.Kind.full, 105.0 / 68), (.sevenASide, 60.0 / 40), (.fiveASide, 40.0 / 25)])
    func fitsTheKindsAspectInsideTheRect(kind: Pitch.Kind, aspect: Double) {
        let wide = CGRect(x: 0, y: 0, width: 400, height: 500)    // height-limited
        let tall = CGRect(x: 0, y: 0, width: 300, height: 900)    // width-limited
        for rect in [wide, tall] {
            let r = BoardGeometry(kind: kind, fitting: rect).pitchRect
            #expect(abs(Double(r.height / r.width) - aspect) < 1e-9)
            #expect(rect.insetBy(dx: -0.001, dy: -0.001).contains(r))
            #expect(abs(r.midX - rect.midX) < 1e-9 && abs(r.midY - rect.midY) < 1e-9)
        }
        #expect(BoardGeometry(kind: kind, fitting: tall).pitchRect.width == 300)
        #expect(BoardGeometry(kind: kind, fitting: wide).pitchRect.height == 500)
    }

    @Test func tokenRadiusFollowsThePitchWidth() {
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 334, height: 2000))
        #expect(abs(g.tokenRadius - 334 * 0.038) < 1e-9)
    }

    @Test func hitTestFindsTheNearestTokenWithin22Points() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.restingState(step: 0, in: hero)
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 334, height: 516))
        let three = g.point(try #require(state.positions["h3"]))
        #expect(g.hitToken(at: three, positions: state.positions, tokens: hero.tokens) == "h3")
        #expect(g.hitToken(at: CGPoint(x: three.x + 21, y: three.y), positions: state.positions, tokens: hero.tokens) == "h3")
        #expect(g.hitToken(at: CGPoint(x: three.x + 23, y: three.y), positions: state.positions, tokens: hero.tokens) == nil)
        // Nothing near the centre spot in step 1.
        #expect(g.hitToken(at: g.point(.centre), positions: state.positions, tokens: hero.tokens) == nil)
    }

    @Test func theBallSitsAtItsCarriersFeetAndIsHitThere() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.restingState(step: 0, in: hero)  // 8 carries the ball in step 1
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 334, height: 516))
        let centres = g.drawnCentres(positions: state.positions, tokens: hero.tokens)
        let ball = try #require(centres["ball"]), at = g.point(try #require(state.positions["ball"]))
        let r = g.tokenRadius
        #expect(abs(ball.x - (at.x + r * 0.95)) < 1e-9 && abs(ball.y - (at.y + r * 0.95)) < 1e-9)
        // A ball away from every player is drawn where it is.
        var loose = state.positions
        loose["ball"] = Point(x: 0.5, y: 0.5)
        #expect(g.drawnCentres(positions: loose, tokens: hero.tokens)["ball"] == g.point(.centre))
        #expect(g.hitToken(at: ball, positions: state.positions, tokens: hero.tokens) == "ball")
    }
}
