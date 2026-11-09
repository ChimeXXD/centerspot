import Foundation
import Testing
@testable import CenterSpot

/// D-96: every scenario is a ready-made move, and `mockup/scenario-motion.js` is the spec. `Fixtures/scenario-moves.json`
/// holds what the mockup builds for four shapes across the three sizes, every scenario each offers, attacking and
/// defending; the app must build the same steps: durations, notes, positions and arrows.
struct ScenarioMoveTests {
    struct File: Decodable {
        struct Step: Decodable {
            let d: Double
            let n: String
            let h: [[Double]]
            let a: [[Double]]
            let b: [Double]
            let w: [Arrow]

            struct Arrow: Decodable {
                let kind: String
                let points: [Double]

                init(from decoder: any Decoder) throws {
                    var c = try decoder.unkeyedContainer()
                    kind = try c.decode(String.self)
                    points = try c.decode([Double].self)
                }
            }
        }
        struct Move: Decodable {
            let id: String
            let formation: String
            let attacking: Bool
            let steps: [Step]
        }
        let moves: [Move]
    }

    private static func file() throws -> File {
        let url = try #require(Bundle(for: MoveBundleToken.self).url(forResource: "scenario-moves", withExtension: "json"))
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
    }

    private static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0015 }

    @Test func everyScenarioHasAMove() {
        for scenario in Scenario.all {
            #expect(ScenarioMotion.scripts[scenario.id] != nil, "\(scenario.id)")
        }
    }

    @Test func everyMoveIsBuiltAsTheMockupBuildsIt() throws {
        let moves = try Self.file().moves
        #expect(moves.count == 158)
        for move in moves {
            let label = "\(move.id) · \(move.formation) · \(move.attacking ? "attacking" : "defending")"
            let scenario = try #require(Scenario.all.first { $0.id == move.id }, "\(label)")
            let formation = try #require(Presets.shared.formation(move.formation), "\(label)")
            let steps = try #require(ScenarioMotion.build(scenario, formation: formation, attacking: move.attacking), "\(label)")
            #expect(steps.count == move.steps.count, "\(label): \(steps.count) steps")
            for (k, (got, want)) in zip(steps, move.steps).enumerated() {
                let at = "\(label) · step \(k + 1)"
                #expect(got.note == want.n, "\(at): “\(got.note)” vs “\(want.n)”")
                #expect(Self.close(got.duration, want.d), "\(at): duration")
                #expect(got.home.map(\.number) == want.h.map { Int($0[0]) }, "\(at): home numbers")
                #expect(got.away.map(\.number) == want.a.map { Int($0[0]) }, "\(at): away numbers")
                for (p, w) in zip(got.home + got.away, want.h + want.a)
                where !Self.close(p.point.x, w[1]) || !Self.close(p.point.y, w[2]) {
                    Issue.record("\(at): \(p.number) at \(p.point), mockup \(w[1]), \(w[2])")
                }
                #expect(Self.close(got.ball.x, want.b[0]) && Self.close(got.ball.y, want.b[1]), "\(at): ball \(got.ball)")
                #expect(got.arrows.map(\.kind.rawValue) == want.w.map(\.kind), "\(at): arrow kinds")
                for (arrow, w) in zip(got.arrows, want.w) {
                    let flat = arrow.points.flatMap { [$0.x, $0.y] }
                    #expect(flat.count == w.points.count && zip(flat, w.points).allSatisfy { Self.close($0, $1) }, "\(at): arrow points")
                }
            }
        }
    }
}

private final class MoveBundleToken {}
