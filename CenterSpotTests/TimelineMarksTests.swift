import Foundation
import Testing
@testable import CenterSpot

/// Marks on the pure timeline (D-06, D-65): they fade with their step like arrows (D-46: in over the first 0.2 s of
/// the hold, out over the last 0.2 s of the move; the last step's stay), a mark with the same id on the next step eases
/// into it instead, and lines and rings follow the players' interpolated positions.
///
/// `small()` has three 1.2 s steps: step 1 holds 0…0.3 and moves 0.3…1.5, step 2 holds 1.5…1.8 and moves 1.8…3.0,
/// step 3 holds 3.0…3.3 (the end).
struct TimelineMarksTests {
    typealias T = TestTactics

    private func opacity(of id: String, at t: Double, in tactic: Tactic) -> Double {
        Timeline.state(at: t, in: tactic).marks.first { $0.id == id }?.opacity ?? 0
    }

    private func zone(_ id: String, at t: Double, in tactic: Tactic) throws -> Zone {
        let mark = try #require(Timeline.state(at: t, in: tactic).marks.first { $0.id == id }, "no \(id) at \(t)")
        guard case .zone(let zone) = mark.shape else { throw Missing.zone }
        return zone
    }

    private enum Missing: Error { case zone, heat }

    @Test func aStepsMarksFadeInAndOutLikeItsArrows() {
        let tactic = T.small(marks: T.someMarks, onStep: 1)
        for id in T.someMarks.ids {
            #expect(opacity(of: id, at: 1.49, in: tactic) == 0, "\(id): not on step 1")
            #expect(opacity(of: id, at: 1.5, in: tactic) == 0, "\(id): the step has just begun")
            #expect(abs(opacity(of: id, at: 1.6, in: tactic) - 0.5) < 1e-9, "\(id): half faded in")
            #expect(abs(opacity(of: id, at: 1.7, in: tactic) - 1) < 1e-9, "\(id)")
            #expect(opacity(of: id, at: 2.5, in: tactic) == 1, "\(id): shown through the move")
            #expect(abs(opacity(of: id, at: 2.9, in: tactic) - 0.5) < 1e-9, "\(id): half faded out")
            #expect(opacity(of: id, at: 3.0, in: tactic) == 0, "\(id): gone on step 3")
        }
    }

    @Test func theLastStepsMarksStay() {
        let tactic = T.small(marks: T.someMarks, onStep: 2)
        #expect(abs(opacity(of: "z1", at: 3.1, in: tactic) - 0.5) < 1e-9)
        #expect(opacity(of: "z1", at: 3.3, in: tactic) == 1)
        #expect(opacity(of: "z1", at: 99, in: tactic) == 1)
    }

    @Test func marksFollowTheArrowsTiming() {
        let tactic = T.small(marks: T.someMarks, onStep: 0)
        for t in stride(from: 0.0, through: 3.3, by: 0.05) {
            let state = Timeline.state(at: t, in: tactic)
            let arrow = state.arrows.first?.opacity ?? 0
            #expect(abs(opacity(of: "z1", at: t, in: tactic) - arrow) < 1e-9, "t = \(t)")
        }
    }

    @Test func aZoneWithTheSameIDOnTheNextStepEasesInsteadOfFading() throws {
        var tactic = T.small(marks: Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.2, w: 0.2, h: 0.2)]), onStep: 0)
        tactic = T.changing(tactic, step: 1) { $0.marks = Marks(zones: [Zone(id: "z1", x: 0.5, y: 0.6, w: 0.4, h: 0.3)]) }
        #expect(try zone("z1", at: 0.3, in: tactic) == Zone(id: "z1", x: 0.1, y: 0.2, w: 0.2, h: 0.2))
        let middle = try zone("z1", at: 0.9, in: tactic)  // half the move, eased: 0.5
        #expect(abs(middle.x - 0.3) < 1e-9 && abs(middle.y - 0.4) < 1e-9, "\(middle)")
        #expect(abs(middle.w - 0.3) < 1e-9 && abs(middle.h - 0.25) < 1e-9, "\(middle)")
        for t in [1.4, 1.49, 1.5, 1.55] { #expect(opacity(of: "z1", at: t, in: tactic) == 1, "never fades: t = \(t)") }
        #expect(try zone("z1", at: 1.5, in: tactic) == Zone(id: "z1", x: 0.5, y: 0.6, w: 0.4, h: 0.3))
        // Through the move it is never far from where the eased players are: no jump at the step boundary.
        let before = try zone("z1", at: 1.4999, in: tactic), after = try zone("z1", at: 1.5, in: tactic)
        #expect(abs(before.x - after.x) < 1e-3 && abs(before.w - after.w) < 1e-3)
    }

    @Test func heatEasesItsSpotAndSize() throws {
        var tactic = T.small(marks: Marks(glows: [Glow(id: "g1", target: .spot(Point(x: 0.2, y: 0.2), radius: 0.05))]), onStep: 0)
        tactic = T.changing(tactic, step: 1) {
            $0.marks = Marks(glows: [Glow(id: "g1", target: .spot(Point(x: 0.6, y: 0.4), radius: 0.15))])
        }
        let mark = try #require(Timeline.state(at: 0.9, in: tactic).marks.first)
        guard case .glow(let glow) = mark.shape, case let .spot(centre, radius) = glow.target else { throw Missing.heat }
        #expect(abs(centre.x - 0.4) < 1e-9 && abs(centre.y - 0.3) < 1e-9 && abs(radius - 0.1) < 1e-9)
        #expect(mark.opacity == 1)
    }

    @Test func aChangedMarkUnderTheSameIDFadesOutAndIn() {
        let first = Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.2, w: 0.2, h: 0.2, colour: .lime)],
                          lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])], glows: [Glow(id: "g1", target: .token("h4"))])
        let second = Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.2, w: 0.2, h: 0.2, colour: .sky)],
                           lines: [ShapeLine(id: "l1", tokens: ["h9", "h4"])], glows: [Glow(id: "g1", target: .token("h9"))])
        var tactic = T.small(marks: first, onStep: 0)
        tactic = T.changing(tactic, step: 1) { $0.marks = second }
        for id in ["z1", "l1", "g1"] {
            #expect(abs(opacity(of: id, at: 1.4, in: tactic) - 0.5) < 1e-9, "\(id) fades out")
            #expect(abs(opacity(of: id, at: 1.6, in: tactic) - 0.5) < 1e-9, "\(id) fades in")
        }
    }

    @Test func aSameLineOrRingCarriesOn() {
        let marks = Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])], glows: [Glow(id: "g1", target: .token("h9"))])
        var tactic = T.small(marks: marks, onStep: 0)
        tactic = T.changing(tactic, step: 1) { $0.marks = marks }
        for t in [1.4, 1.5, 1.6] {
            #expect(opacity(of: "l1", at: t, in: tactic) == 1, "t = \(t)")
            #expect(opacity(of: "g1", at: t, in: tactic) == 1, "t = \(t)")
        }
    }

    @Test func lineCornersFollowThePlayersMidMove() throws {
        let tactic = T.small(marks: Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])]), onStep: 0)
        let state = Timeline.state(at: 0.9, in: tactic)
        let mark = try #require(state.marks.first)
        guard case .line(let line) = mark.shape else { Issue.record("not a line"); return }
        let corners = state.corners(of: line)
        #expect(corners == [try #require(state.positions["h4"]), try #require(state.positions["h9"])])
        // h4 is between its step 1 and step 2 spots (0.2 → 0.25), so the corner moved with them.
        let h4 = try #require(corners.first)
        #expect(h4.y > 0.2 && h4.y < 0.25, "\(h4)")
    }

    @Test func theRestingBoardShowsEveryMarkFully() {
        let tactic = T.small(marks: T.someMarks, onStep: 1)
        let resting = Timeline.restingState(step: 1, in: tactic)
        #expect(resting.marks.map(\.id) == T.someMarks.ids)
        #expect(resting.marks.allSatisfy { $0.opacity == 1 })
        #expect(resting.marks == Timeline.state(at: 1.8, in: tactic).marks, "the end of the hold, as for arrows")
        #expect(Timeline.restingState(step: 0, in: tactic).marks.isEmpty)
    }

    @Test func marksArePure() {
        let tactic = T.small(marks: T.someMarks, onStep: 1)
        for t in [0, 1.55, 2.2, 2.95, 3.3] {
            #expect(Timeline.state(at: t, in: tactic) == Timeline.state(at: t, in: tactic))
        }
    }
}
