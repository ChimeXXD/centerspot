import Foundation
import Testing
@testable import CenterSpot

/// The size cap applies to the tactic as CenterSpot saves it, not only to the bytes that came in (D6-3 fuzz). Repairs can
/// grow a file: every step gets a position for every token, so a small file with long token ids, or one near the cap
/// with positions left out, would save as a file that the library then can't reopen.
extension ImportValidationTests {
    /// 30 tokens with 2,000-character ids and 40 steps that place none of them: about 65 KB in, 2.5 MB once repaired.
    @Test func aRepairThatGrowsPastTheCapIsRefused() throws {
        var tactic = T.small()
        tactic.tokens = (0..<30).map { Token(id: String(repeating: "x", count: 2_000) + "\($0)", kind: .cone) }
        tactic.phases[0].steps = (1...40).map { Step(id: "s\($0)") }
        let data = try T.data(tactic)
        #expect(data.count < TacticFormat.maxByteCount / 2)
        #expect(T.refusal(data) == .unreadable)
    }

    /// The same shape with short ids grows a little and still opens.
    @Test func aRepairThatStaysUnderTheCapOpens() throws {
        var tactic = T.small()
        tactic.tokens = (0..<30).map { Token(id: "c\($0)", kind: .cone) }
        tactic.phases[0].steps = (1...40).map { Step(id: "s\($0)") }
        let open = try TacticFormat.decode(T.data(tactic))
        #expect(open.phases[0].steps.allSatisfy { $0.positions.count == 30 })
    }

    /// A busy board written compactly fits the cap, but its pretty-printed form doesn't: CenterSpot saves it compactly
    /// rather than writing a file it can't read back.
    @Test func aBigTacticSavesCompactlyAndReopens() throws {
        var tactic = T.small()
        tactic.tokens = (0..<30).map { Token(id: "c\($0)", kind: .cone) }
        let arrow = Arrow(kind: .pass, points: [T.p(0.125, 0.25), T.p(0.375, 0.5), T.p(0.625, 0.75)])
        tactic.phases[0].steps = (1...40).map { n in
            Step(
                id: "s\(n)",
                positions: Dictionary(uniqueKeysWithValues: (0..<30).map { ("c\($0)", T.p(0.5, 0.25)) }),
                arrows: Array(repeating: arrow, count: Step.maxArrows)
            )
        }
        let compact = try T.data(tactic)
        #expect(compact.count <= TacticFormat.maxByteCount)

        let open = try TacticFormat.decode(compact)
        let saved = try TacticFormat.encode(open)
        #expect(saved.count <= TacticFormat.maxByteCount)
        #expect(try TacticFormat.decode(saved) == open)
    }

    /// A small tactic is still saved pretty-printed, so files diff and read well.
    @Test func aSmallTacticSavesPrettyPrinted() throws {
        let saved = try #require(String(data: TacticFormat.encode(T.small()), encoding: .utf8))
        #expect(saved.contains("\n  \"id\" : "))
    }
}
