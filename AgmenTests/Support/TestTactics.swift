import Foundation
import Testing
@testable import Agmen

/// The `.tactic` fixtures bundled with the tests (`AgmenTests/Fixtures/`).
enum Fixtures {
    static let names = ["overlap-left", "five-a-side-long-ball", "full-11v11"]

    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: FixtureBundleToken.self).url(forResource: name, withExtension: "tactic"))
        return try Data(contentsOf: url)
    }

    static func tactic(_ name: String) throws -> Tactic {
        try TacticFormat.decode(data(name))
    }
}

private final class FixtureBundleToken {}

/// Small hand-built tactics and JSON helpers for the import rules.
enum TestTactics {
    /// Two home players, one away player and the ball over three steps; `h9` has a run in step 1.
    static func small() -> Tactic {
        Tactic(
            id: "11111111-2222-3333-4444-555555555555",
            title: "Small",
            pitch: Pitch(kind: .full, style: .plain),
            sides: [
                Side(id: .home, name: "Us", colour: .blue),
                Side(id: .away, name: "Them", colour: .orange),
            ],
            tokens: [
                Token(id: "h4", kind: .player, side: .home, number: 4, roleID: "centre-back"),
                Token(id: "h9", kind: .player, side: .home, number: 9, name: "Tolu", roleID: "striker"),
                Token(id: "a5", kind: .player, side: .away, number: 5),
                Token(id: "ball", kind: .ball),
            ],
            phases: [
                Phase(id: .main, name: "Main", steps: [
                    Step(
                        id: "s1",
                        positions: ["h4": p(0.4, 0.2), "h9": p(0.5, 0.6), "a5": p(0.5, 0.8), "ball": p(0.4, 0.21)],
                        runs: ["h9": Path(points: [p(0.5, 0.6), p(0.6, 0.7), p(0.55, 0.8)])],
                        arrows: [Arrow(kind: .pass, points: [p(0.4, 0.21), p(0.55, 0.8)])],
                        note: "Ball over the top"
                    ),
                    Step(
                        id: "s2",
                        positions: ["h4": p(0.4, 0.25), "h9": p(0.55, 0.8), "a5": p(0.52, 0.78), "ball": p(0.55, 0.8)]
                    ),
                    Step(
                        id: "s3",
                        positions: ["h4": p(0.4, 0.3), "h9": p(0.5, 0.9), "a5": p(0.5, 0.85), "ball": p(0.5, 0.97)]
                    ),
                ]),
            ],
            app: .init(createdWith: "TestTactics")
        )
    }

    static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

    /// Compact, key-sorted JSON, so tests can patch exact substrings such as `"kind":"ball"`.
    static func json(_ tactic: Tactic) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try #require(String(data: encoder.encode(tactic), encoding: .utf8))
    }

    /// Encodes `tactic`, replaces `target` with `replacement` (which must occur), and returns the bytes.
    static func patched(_ tactic: Tactic, replacing target: String, with replacement: String) throws -> Data {
        let text = try json(tactic)
        #expect(text.contains(target), "patch target \(target) not found")
        return Data(text.replacingOccurrences(of: target, with: replacement).utf8)
    }

    static func data(_ tactic: Tactic) throws -> Data {
        Data(try json(tactic).utf8)
    }

    /// Decodes and returns the error, or `nil` if the file opened.
    static func refusal(_ data: Data) -> TacticFormatError? {
        do throws(TacticFormatError) {
            _ = try TacticFormat.decode(data)
            return nil
        } catch {
            return error
        }
    }
}
