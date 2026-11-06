import Foundation
import Testing
@testable import Agmen

/// SPEC §3 and §9 Core: `Timeline.state(at:in:)` is a pure function of `t` and the tactic.
struct TimelineTests {
    /// One player moving (0.2, 0.2) → (0.6, 0.8) over a 1.0 s move, a runner with an L-shaped run,
    /// and one arrow on each step. Timeline: hold 0…0.3, move 0.3…1.3, final hold 1.3…1.6.
    private let tactic = Tactic(
        id: "timeline",
        title: "Timeline",
        pitch: Pitch(kind: .full),
        sides: [Side(id: .home, name: "Us", colour: .blue), Side(id: .away, name: "Them", colour: .orange)],
        tokens: [
            Token(id: "mover", kind: .player, side: .home, number: 8),
            Token(id: "runner", kind: .player, side: .home, number: 9),
        ],
        phases: [Phase(id: .main, name: "Main", steps: [
            Step(
                id: "s1",
                duration: 1.0,
                positions: ["mover": pt(0.2, 0.2), "runner": pt(0.5, 0.2)],
                runs: ["runner": Path(points: [pt(0.5, 0.2), pt(0.5, 0.6), pt(0.7, 0.6)])],
                arrows: [Arrow(kind: .pass, points: [pt(0.2, 0.2), pt(0.6, 0.8)])]
            ),
            Step(
                id: "s2",
                duration: 1.0,
                positions: ["mover": pt(0.6, 0.8), "runner": pt(0.7, 0.6)],
                arrows: [Arrow(kind: .press, points: [pt(0.6, 0.8), pt(0.6, 0.9)])]
            ),
        ])]
    )

    private func expectClose(_ a: Point?, _ b: Point, within tolerance: Double = 0.001,
                             sourceLocation: SourceLocation = #_sourceLocation) {
        guard let a else {
            Issue.record("missing point", sourceLocation: sourceLocation)
            return
        }
        #expect(abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance,
                "\(a) is not within \(tolerance) of \(b)", sourceLocation: sourceLocation)
    }

    // MARK: Easing

    @Test(arguments: [(0.0, 0.0), (0.25, 0.0625), (0.5, 0.5), (0.75, 0.9375), (1.0, 1.0), (-1.0, 0.0), (2.0, 1.0)])
    func easeInOutCubic(progress: Double, eased: Double) {
        #expect(abs(Easing.inOutCubic(progress) - eased) < 1e-12)
    }

    // MARK: Duration

    @Test func durationIsHoldPlusMovePerStepPlusAFinalHold() throws {
        #expect(abs(Timeline.duration(of: tactic.phases[0]) - 1.6) < 1e-9)
        // Hero: (0.3 + 1.2) + (0.3 + 1.4) + (0.3 + 1.2) × 2 + 0.3
        let hero = try Fixtures.tactic("overlap-left")
        #expect(abs(Timeline.duration(of: hero.phases[0]) - 6.5) < 1e-9)
        #expect(abs(Timeline.duration(of: Phase(id: .main, name: "Main", steps: [Step(id: "s1")])) - 0.3) < 1e-9)
    }

    // MARK: Positions

    @Test func startEqualsStepOne() {
        let state = Timeline.state(at: 0, in: tactic)
        #expect(state.positions == tactic.phases[0].steps[0].positions)
        #expect(state.stepIndex == 0)
    }

    @Test func endEqualsTheLastStep() {
        let state = Timeline.state(at: 1.6, in: tactic)
        #expect(state.positions == tactic.phases[0].steps[1].positions)
        #expect(state.stepIndex == 1)
    }

    @Test(arguments: [-5.0, -.infinity, .nan])
    func timeBeforeTheStartClampsToTheStart(t: Double) {
        #expect(Timeline.state(at: t, in: tactic) == Timeline.state(at: 0, in: tactic))
    }

    @Test(arguments: [1.7, 100.0, .infinity])
    func timeAfterTheEndClampsToTheEnd(t: Double) {
        #expect(Timeline.state(at: t, in: tactic) == Timeline.state(at: 1.6, in: tactic))
    }

    @Test func tokensHoldStillDuringTheHold() {
        expectClose(Timeline.state(at: 0.29, in: tactic).positions["mover"], pt(0.2, 0.2), within: 1e-12)
    }

    /// Hand-computed: u = 0.25 → ease 0.0625; u = 0.5 → 0.5; u = 0.75 → 0.9375.
    @Test(arguments: [(0.55, 0.0625), (0.8, 0.5), (1.05, 0.9375)])
    func midMoveFollowsEaseInOutCubic(t: Double, eased: Double) {
        let state = Timeline.state(at: t, in: tactic)
        expectClose(state.positions["mover"], pt(0.2 + 0.4 * eased, 0.2 + 0.6 * eased))
        #expect(state.stepIndex == 0)
    }

    /// The run is 42 m up the pitch (0.4 × 105) then 13.6 m across (0.2 × 68); 55.6 m in all.
    /// Halfway (u = 0.5, ease 0.5) is 27.8 m along: on the first leg, y = 0.2 + 0.4 × 27.8 / 42.
    @Test func tokenWithARunFollowsItByArcLength() {
        expectClose(Timeline.state(at: 0.8, in: tactic).positions["runner"], pt(0.5, 0.2 + 0.4 * 27.8 / 42))
        // u = 0.75 → ease 0.9375 → 52.125 m: 10.125 m into the second leg.
        expectClose(Timeline.state(at: 1.05, in: tactic).positions["runner"], pt(0.5 + 0.2 * 10.125 / 13.6, 0.6))
    }

    @Test func tokenMissingFromTheNextStepStaysWhereItWas() {
        var unrepaired = tactic
        unrepaired.phases[0].steps[1].positions["mover"] = nil
        expectClose(Timeline.state(at: 0.8, in: unrepaired).positions["mover"], pt(0.2, 0.2), within: 1e-12)
    }

    @Test func tokenMissingFromALaterStepKeepsItsLastPosition() {
        var unrepaired = tactic
        unrepaired.phases[0].steps[1].positions["mover"] = nil
        // At the end of the move and through step 2's hold it stays put instead of jumping to the centre.
        expectClose(Timeline.state(at: 1.3, in: unrepaired).positions["mover"], pt(0.2, 0.2), within: 1e-12)
        expectClose(Timeline.state(at: 1.6, in: unrepaired).positions["mover"], pt(0.2, 0.2), within: 1e-12)
    }

    @Test func staleRunIsAnchoredSoTheTokenNeverJumps() {
        var edited = tactic
        edited.phases[0].steps[0].positions["runner"] = pt(0.3, 0.1)  // moved after the run was drawn
        edited.phases[0].steps[1].positions["runner"] = pt(0.9, 0.7)
        expectClose(Timeline.state(at: 0.3, in: edited).positions["runner"], pt(0.3, 0.1), within: 1e-12)
        expectClose(Timeline.state(at: 1.2999999, in: edited).positions["runner"], pt(0.9, 0.7))
    }

    @Test func sameInputGivesTheSameOutput() throws {
        let hero = try Fixtures.tactic("overlap-left")
        for t in stride(from: 0.0, through: 6.5, by: 0.37) {
            #expect(Timeline.state(at: t, in: hero) == Timeline.state(at: t, in: hero))
        }
    }

    // MARK: Arrows

    @Test func arrowsFadeInOverTheFirstTwoTenthsOfTheHold() {
        #expect(Timeline.state(at: 0, in: tactic).arrows.isEmpty)
        let half = Timeline.state(at: 0.1, in: tactic).arrows
        #expect(half.map(\.arrow.kind) == [.pass])
        #expect(abs((half.first?.opacity ?? 0) - 0.5) < 1e-9)
        #expect(Timeline.state(at: 0.25, in: tactic).arrows.map(\.opacity) == [1])
        #expect(Timeline.state(at: 0.8, in: tactic).arrows.map(\.opacity) == [1])
    }

    @Test func arrowsFadeOutAsTheMoveEnds() {
        let fading = Timeline.state(at: 1.2, in: tactic).arrows
        #expect(fading.map(\.arrow.kind) == [.pass])
        #expect(abs((fading.first?.opacity ?? 0) - 0.5) < 1e-9)
        // At the end of the move step 2 begins: its arrow starts fading in, step 1's is gone.
        #expect(Timeline.state(at: 1.3, in: tactic).arrows.isEmpty)
        #expect(Timeline.state(at: 1.6, in: tactic).arrows.map(\.arrow.kind) == [.press])
        #expect(Timeline.state(at: 1.6, in: tactic).arrows.map(\.opacity) == [1])
    }
}

private func pt(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
