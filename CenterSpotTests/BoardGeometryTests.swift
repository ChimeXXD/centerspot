import CoreGraphics
import Foundation
import Testing
@testable import CenterSpot

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

    /// D-59: a stroke starts on a player when it can; a loose ball counts; cones and grass don't.
    @Test func aStrokeStartsOnThePlayerBeforeTheBallAtTheirFeet() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.restingState(step: 0, in: hero)
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 334, height: 516))
        let ball = try #require(g.drawnCentres(positions: state.positions, tokens: hero.tokens)["ball"])
        #expect(g.strokeStart(at: ball, positions: state.positions, tokens: hero.tokens) == "h8", "8 carries it")
        var loose = state.positions
        loose["ball"] = Point(x: 0.5, y: 0.5)
        #expect(g.strokeStart(at: g.point(.centre), positions: loose, tokens: hero.tokens) == "ball")
        let three = g.point(try #require(state.positions["h3"]))
        #expect(g.strokeStart(at: three, positions: state.positions, tokens: hero.tokens) == "h3")
        #expect(g.strokeStart(at: g.point(.centre), positions: state.positions, tokens: hero.tokens) == nil)
        _ = TacticEdits.addToken(.cone, in: &hero)
        let withCone = Timeline.restingState(step: 0, in: hero).positions
        #expect(g.strokeStart(at: g.point(.centre), positions: withCone, tokens: hero.tokens) == nil, "a cone is grass")
    }

    /// A loose ball just out of a player's reach but inside their hit radius: starting on the ball picks the ball.
    @Test func aLooseBallNearAPlayerStartsItsOwnStroke() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 345, height: 345 * 105 / 68))
        var positions = Timeline.restingState(step: 0, in: hero).positions
        let six = try #require(positions["h6"])
        // 18 pt to the right of 6: past the 1.2-radius reach (about 15.7 pt), inside the 22 pt hit radius.
        positions["ball"] = Point(x: six.x + 18 / 345, y: six.y)
        let ball = try #require(g.drawnCentres(positions: positions, tokens: hero.tokens)["ball"])
        #expect(ball == g.point(try #require(positions["ball"])), "the ball is loose, drawn where it is")
        #expect(g.strokeStart(at: ball, positions: positions, tokens: hero.tokens) == "ball")
        #expect(g.strokeStart(at: g.point(six), positions: positions, tokens: hero.tokens) == "h6", "on 6 is still 6")
    }

    /// Chime's recording, 7 Nov: the ball jumped as it left or reached a player, because the "at their feet" offset
    /// switched on and off at one distance (17.6 pt in one frame at t = 3.95). Sampled at 60 fps across the hero,
    /// the drawn ball's motion may change by at most 1 pt from one frame to the next: it speeds up and slows down,
    /// it never leaps.
    @Test func theBallNeverJumpsBetweenFrames() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 345, height: 345 * 105 / 68))
        let duration = Timeline.duration(of: hero.phases[0])
        var points: [CGPoint] = []
        for frame in 0...Int(duration * 60) {
            let state = Timeline.state(at: Double(frame) / 60, in: hero)
            points.append(try #require(g.drawnCentres(positions: state.positions, tokens: hero.tokens, carry: state.carry)["ball"]))
        }
        var worst = (change: 0.0, t: 0.0)
        for i in 2..<points.count {
            let v1 = CGPoint(x: points[i - 1].x - points[i - 2].x, y: points[i - 1].y - points[i - 2].y)
            let v2 = CGPoint(x: points[i].x - points[i - 1].x, y: points[i].y - points[i - 1].y)
            let change = hypot(v2.x - v1.x, v2.y - v1.y)
            if change > worst.change { worst = (change, Double(i) / 60) }
        }
        #expect(worst.change <= 1, "the ball's motion changes by \(worst.change) pt in one frame at t = \(worst.t)")
    }

    /// A ball 1 disc radius from its carrier (between full and no carry) is drawn in the same place in the editor
    /// (`restingState`, no carry) and in playback at the end of the hold, so pressing play never nudges it.
    @Test func theBallIsDrawnTheSameAtRestAndInPlayback() throws {
        var hero = try Fixtures.tactic("overlap-left")
        let eight = try #require(hero.phases[0].steps[0].positions["h8"])
        hero.phases[0].steps[0].positions["ball"] = Point(x: eight.x + Possession.discRadius, y: eight.y)
        let g = BoardGeometry(kind: .full, fitting: CGRect(x: 0, y: 0, width: 345, height: 345 * 105 / 68))
        let resting = Timeline.restingState(step: 0, in: hero)
        let timed = Timeline.state(at: Timeline.hold, in: hero)
        let editor = try #require(g.drawnCentres(positions: resting.positions, tokens: hero.tokens)["ball"])
        let played = try #require(g.drawnCentres(positions: timed.positions, tokens: hero.tokens, carry: timed.carry)["ball"])
        #expect(hypot(editor.x - played.x, editor.y - played.y) < 0.01)
    }

    /// Bigger discs (a library card's `tokenScale`) draw the ball further out at the carrier's feet, but don't widen
    /// who has it: a ball 1.3 board disc radii from a player is loose on the board and on a card alike.
    @Test func biggerDiscsDontWidenTheCarry() {
        var g = BoardGeometry(pitchRect: CGRect(x: 0, y: 0, width: 300, height: 450))
        let tokens = [Token(id: "p", kind: .player, side: .home), Token(id: "b", kind: .ball)]
        let p = Point(x: 0.5, y: 0.5)
        let ball = Point(x: 0.5 + 1.3 * BoardGeometry.tokenRadiusRatio, y: 0.5)
        let flat = g.drawnCentres(positions: ["p": p, "b": ball], tokens: tokens)
        g.tokenScale = 1.8
        let card = g.drawnCentres(positions: ["p": p, "b": ball], tokens: tokens)
        #expect(flat["b"] == g.point(ball), "loose on the board")
        #expect(card["b"] == g.point(ball), "and loose on the card")
    }
}
