import Foundation
import Testing
@testable import Agmen

/// SPEC §9 Core: one case per row of docs/FORMAT.md's Rules table. This file holds the "refuse" rows;
/// `ImportValidationTests+Repairs.swift` holds the "repair" rows.
struct ImportValidationTests {
    typealias T = TestTactics

    @Test func aValidFileOpensUnchanged() throws {
        let small = T.small()
        #expect(try TacticFormat.decode(T.data(small)) == small)
    }

    @Test func errorsUseThePlainMessages() {
        #expect(TacticFormatError.newerVersion.message == "Made with a newer version of Agmen.")
        #expect(TacticFormatError.unreadable.message == "This file isn't a tactic we can open.")
        #expect(TacticFormatError.unreadable.localizedDescription == "This file isn't a tactic we can open.")
    }

    @Test func garbageIsRefused() {
        #expect(T.refusal(Data()) == .unreadable)
        #expect(T.refusal(Data("hello".utf8)) == .unreadable)
        #expect(T.refusal(Data("[1, 2, 3]".utf8)) == .unreadable)
    }

    /// Under the size cap but nested 100,000 deep: refused, not a stack overflow.
    @Test func deeplyNestedJSONIsRefused() {
        let depth = 100_000
        let text = #"{"schemaVersion":1,"x":"# + String(repeating: "[", count: depth) + String(repeating: "]", count: depth) + "}"
        #expect(text.utf8.count <= TacticFormat.maxByteCount)
        #expect(T.refusal(Data(text.utf8)) == .unreadable)
    }

    @Test func missingRequiredFieldIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"title\":\"Small\",", with: "")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: Size

    /// Valid JSON padded with trailing spaces, so only the byte count can refuse it.
    private func padded(to byteCount: Int) throws -> Data {
        var data = try T.data(T.small())
        data.append(Data(repeating: UInt8(ascii: " "), count: byteCount - data.count))
        return data
    }

    @Test func overSizeCapIsRefused() throws {
        #expect(T.refusal(try padded(to: TacticFormat.maxByteCount + 1)) == .unreadable)
        #expect(T.refusal(Data(repeating: UInt8(ascii: "{"), count: 1_000_000)) == .unreadable)
    }

    @Test func exactlyAtSizeCapOpens() throws {
        #expect(T.refusal(try padded(to: TacticFormat.maxByteCount)) == nil)
    }

    // MARK: schemaVersion

    @Test(arguments: [
        ("2", TacticFormatError.newerVersion),
        ("99", .newerVersion),
        ("0", .unreadable),
        ("-1", .unreadable),
        ("1.5", .unreadable),
        ("\"1\"", .unreadable),
        ("null", .unreadable),
    ])
    func schemaVersionOtherThanOneIsRefused(version: String, expected: TacticFormatError) throws {
        let data = try T.patched(T.small(), replacing: "\"schemaVersion\":1", with: "\"schemaVersion\":\(version)")
        #expect(T.refusal(data) == expected)
    }

    @Test func newerVersionWinsEvenWhenTheShapeIsUnknown() {
        #expect(T.refusal(Data(#"{"schemaVersion": 2, "board": [1, 2]}"#.utf8)) == .newerVersion)
    }

    @Test func missingSchemaVersionIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"schemaVersion\":1,", with: "")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: Coordinates (NaN and infinity refuse; clamping is in Repairs)

    @Test(arguments: ["NaN", "nan", "Infinity", "-Infinity", "1e999", "-1e999"])
    func nonFinitePositionIsRefused(literal: String) throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].positions["a5"] = T.p(0.123, 0.5)
        let data = try T.patched(tactic, replacing: "0.123", with: literal)
        #expect(T.refusal(data) == .unreadable)
    }

    @Test func nonFiniteArrowPointIsRefused() throws {
        var tactic = T.small()
        tactic.phases[0].steps[0].arrows[0].points[1] = T.p(0.5, 0.321)
        let data = try T.patched(tactic, replacing: "0.321", with: "1e999")
        #expect(T.refusal(data) == .unreadable)
    }

    @Test func nonFiniteDurationIsRefused() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].duration = 1.234
        let data = try T.patched(tactic, replacing: "1.234", with: "1e999")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: pitch.kind

    @Test func unknownPitchKindIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"kind\":\"full\"", with: "\"kind\":\"futsal\"")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: sides

    @Test func oneSideIsRefused() throws {
        var tactic = T.small()
        tactic.sides.removeLast()
        tactic.tokens.removeAll { $0.side == .away }
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func threeSidesAreRefused() throws {
        var tactic = T.small()
        tactic.sides.append(Side(id: .away, name: "Others", colour: .red))
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func twoHomeSidesAreRefused() throws {
        var tactic = T.small()
        tactic.sides[1].id = .home
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func unknownSideIDIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"id\":\"away\"", with: "\"id\":\"visitors\"")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: tokens

    private func tactic(withTokenCount count: Int) -> Tactic {
        var tactic = T.small()
        tactic.tokens = (0..<count).map { Token(id: "c\($0)", kind: .cone) }
        tactic.phases[0].steps = [Step(id: "s1")]
        return tactic
    }

    @Test func thirtyOneTokensAreRefused() throws {
        #expect(T.refusal(try T.data(tactic(withTokenCount: 31))) == .unreadable)
        #expect(T.refusal(try T.data(tactic(withTokenCount: 30))) == nil)
    }

    @Test func duplicateTokenIDIsRefused() throws {
        var tactic = T.small()
        tactic.tokens[2].id = "h4"
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func unknownTokenKindIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"kind\":\"ball\"", with: "\"kind\":\"goalpost\"")
        #expect(T.refusal(data) == .unreadable)
    }

    @Test func playerWithoutSideIsRefused() throws {
        var tactic = T.small()
        tactic.tokens[2].side = nil
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func playerOnUnknownSideIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"side\":\"away\"", with: "\"side\":\"neutral\"")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: phases

    @Test func noPhasesAreRefused() throws {
        var tactic = T.small()
        tactic.phases = []
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func threePhasesAreRefused() throws {
        var tactic = T.small()
        let main = tactic.phases[0]
        tactic.phases = [main, Phase(id: .inPossession, name: "In", steps: main.steps),
                         Phase(id: .outOfPossession, name: "Out", steps: main.steps)]
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func twoPhasesOpen() throws {
        var tactic = T.small()
        tactic.phases.append(Phase(id: .outOfPossession, name: "Out", steps: tactic.phases[0].steps))
        #expect(try TacticFormat.decode(T.data(tactic)) == tactic)
    }

    @Test func duplicatePhaseIDIsRefused() throws {
        var tactic = T.small()
        tactic.phases.append(tactic.phases[0])
        #expect(T.refusal(try T.data(tactic)) == .unreadable)
    }

    @Test func unknownPhaseIDIsRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"id\":\"main\"", with: "\"id\":\"setPiece\"")
        #expect(T.refusal(data) == .unreadable)
    }
}
