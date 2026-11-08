import Foundation
import Testing
@testable import Agmen

/// BR-2 (D-66, D-76): where the broadcast camera looks. It follows the ball, or the players moving in the step when
/// there is no ball, smoothed so a pass never whips it; Reduce Motion gets one still view of the whole move. A pure
/// function of the tactic, so playback, scrubbing and export frame the same view at the same `t`.
struct CameraTrackTests {
    private typealias T = TestTactics

    private func expectNear(_ a: Point, _ b: Point, within tolerance: Double = 1e-6,
                            sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(hypot(a.x - b.x, a.y - b.y) <= tolerance, "\(a) is not within \(tolerance) of \(b)",
                sourceLocation: sourceLocation)
    }

    /// `small()` with its ball taken off, and players that move or stand as given.
    private func noBall(_ steps: [[String: Point]]) -> Tactic {
        var tactic = T.small()
        tactic.tokens.removeAll { $0.kind == .ball }
        tactic.phases[0].steps = steps.enumerated().map { Step(id: "s\($0.offset + 1)", positions: $0.element) }
        return tactic
    }

    @Test func theSubjectIsTheBall() {
        let tactic = T.small()
        for t in stride(from: 0.0, through: Timeline.duration(of: tactic.phases[0]), by: 0.25) {
            let ball = Timeline.state(at: t, in: tactic).positions["ball"]
            #expect(CameraTrack.subject(at: t, in: tactic) == ball, "t = \(t)")
        }
    }

    @Test func aStillBallHoldsTheCamera() {
        var tactic = T.small()
        for i in tactic.phases[0].steps.indices { tactic.phases[0].steps[i].positions["ball"] = T.p(0.3, 0.4) }
        tactic.phases[0].steps[0].arrows = []
        let track = CameraTrack(tactic: tactic)
        for t in stride(from: 0.0, through: 3.2, by: 0.1) { expectNear(track.target(at: t), T.p(0.3, 0.4)) }
        expectNear(track.still, T.p(0.3, 0.4))
    }

    @Test func itFollowsTheBallUpThePitch() {
        let tactic = T.small()
        let track = CameraTrack(tactic: tactic)
        let end = Timeline.duration(of: tactic.phases[0])
        let start = track.target(at: 0), finish = track.target(at: end)
        #expect(finish.y > start.y + 0.4, "the ball goes from 0.21 to 0.97; the camera from \(start.y) to \(finish.y)")
        // It ends near the ball, a little behind it (smoothing), never past it.
        #expect(abs(finish.y - 0.97) < 0.12 && finish.y <= 0.97 + 1e-9, "\(finish)")
    }

    /// A long ball over 0.3 s: the ball itself moves a lot between frames; the camera eases across.
    @Test func aQuickPassNeverWhipsTheCamera() {
        var tactic = T.small()
        tactic.phases[0].steps[0].duration = Step.durationRange.lowerBound
        tactic.phases[0].steps[0].positions["ball"] = T.p(0.1, 0.1)
        tactic.phases[0].steps[1].positions["ball"] = T.p(0.9, 0.9)
        let track = CameraTrack(tactic: tactic)
        let end = Timeline.duration(of: tactic.phases[0]), frame = 1 / 30.0
        var ballStep = 0.0, cameraStep = 0.0
        for t in stride(from: 0.0, to: end, by: frame) {
            let a = CameraTrack.subject(at: t, in: tactic)!, b = CameraTrack.subject(at: t + frame, in: tactic)!
            ballStep = max(ballStep, hypot(b.x - a.x, b.y - a.y))
            let c = track.target(at: t), d = track.target(at: t + frame)
            cameraStep = max(cameraStep, hypot(d.x - c.x, d.y - c.y))
        }
        #expect(ballStep > 0.15, "the fixture should be a whip: \(ballStep)")
        #expect(cameraStep < 0.05 && cameraStep < ballStep / 3, "camera \(cameraStep) per frame, ball \(ballStep)")
    }

    @Test func withoutABallItFollowsThePlayersWhoMove() {
        // h4 stands; h9 and a5 move in step 1; nobody moves after step 2.
        let tactic = noBall([
            ["h4": T.p(0.2, 0.2), "h9": T.p(0.6, 0.5), "a5": T.p(0.6, 0.7)],
            ["h4": T.p(0.2, 0.2), "h9": T.p(0.8, 0.7), "a5": T.p(0.4, 0.9)],
            ["h4": T.p(0.2, 0.2), "h9": T.p(0.8, 0.7), "a5": T.p(0.4, 0.9)],
        ])
        // In step 1's hold: the movers' middle where they stand.
        expectNear(CameraTrack.subject(at: 0.1, in: tactic)!, T.p(0.6, 0.6))
        // Mid-move: the middle of where they are now.
        let state = Timeline.state(at: 0.9, in: tactic)
        let h9 = state.positions["h9"]!, a5 = state.positions["a5"]!
        expectNear(CameraTrack.subject(at: 0.9, in: tactic)!, T.p((h9.x + a5.x) / 2, (h9.y + a5.y) / 2))
        // Step 2 moves nobody, and the last step has no move: no subject, so the camera holds.
        #expect(CameraTrack.subject(at: 2.0, in: tactic) == nil)
        #expect(CameraTrack.subject(at: Timeline.duration(of: tactic.phases[0]), in: tactic) == nil)
        let track = CameraTrack(tactic: tactic)
        expectNear(track.target(at: Timeline.duration(of: tactic.phases[0])), T.p(0.6, 0.8), within: 1e-3)
    }

    @Test func whenNobodyEverMovesItHoldsOnTheMiddleOfThePlayers() {
        let standing: [String: Point] = ["h4": T.p(0.2, 0.2), "h9": T.p(0.5, 0.5), "a5": T.p(0.8, 0.5)]
        let track = CameraTrack(tactic: noBall([standing, standing]))
        let middle = T.p(0.5, 0.4)
        for t in [0, 0.5, 1.5] { expectNear(track.target(at: t), middle) }
        expectNear(track.still, middle)
    }

    @Test func reduceMotionFramesTheWholeMoveFromOneSpot() {
        // The ball covers x 0.4…0.55 and y 0.21…0.97 over the move: the still view looks at the middle of that.
        let track = CameraTrack(tactic: T.small())
        expectNear(track.still, T.p(0.475, 0.59), within: 1e-9)
        // The whole area it covers, for the still camera to fit (verifier, 8 Nov: the middle alone left a wing-to-wing
        // switch off screen).
        expectNear(track.span.min, T.p(0.4, 0.21), within: 1e-9)
        expectNear(track.span.max, T.p(0.55, 0.97), within: 1e-9)
        expectNear(track.span.middle, track.still, within: 1e-12)
    }

    @Test func itIsAPureFunctionOfTheTactic() {
        let tactic = T.small()
        let a = CameraTrack(tactic: tactic), b = CameraTrack(tactic: tactic)
        #expect(a == b)
        #expect(a.target(at: 1.234) == b.target(at: 1.234))
        #expect(a.target(at: .nan) == a.target(at: 0))
        #expect(a.target(at: -5) == a.target(at: 0))
        #expect(a.target(at: 1e9) == a.target(at: Timeline.duration(of: tactic.phases[0])))
    }

    @Test func anEmptyTacticLooksAtTheCentreSpot() {
        var tactic = T.small()
        tactic.phases = []
        expectNear(CameraTrack(tactic: tactic).target(at: 1), .centre)
        tactic = T.small()
        tactic.tokens = []
        let track = CameraTrack(tactic: tactic)
        expectNear(track.target(at: 1), .centre)
        expectNear(track.still, .centre)
    }

    @Test func everyFixtureBuildsATrackOnThePitch() throws {
        for name in Fixtures.names {
            let tactic = try Fixtures.tactic(name)
            let track = CameraTrack(tactic: tactic)
            for t in stride(from: 0.0, through: Timeline.duration(of: tactic.phases[0]), by: 0.1) {
                let p = track.target(at: t)
                #expect((0...1).contains(p.x) && (0...1).contains(p.y), "\(name) at \(t): \(p)")
            }
        }
    }
}
