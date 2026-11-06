import Foundation
import Testing
@testable import Agmen

/// FORMAT.md Rules rows whose outcome is "repair": the file opens with the value fixed as written.
extension ImportValidationTests {
    private func opened(_ tactic: Tactic) throws -> Tactic {
        try TacticFormat.decode(T.data(tactic))
    }

    private func steps(_ tactic: Tactic) -> [Step] {
        tactic.phases[0].steps
    }

    // MARK: Coordinates

    @Test func outOfRangeCoordinatesAreClamped() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].positions["a5"] = T.p(-0.2, 1.7)
        tactic.phases[0].steps[0].arrows[0].points[1] = T.p(1.4, -3)
        tactic.phases[0].steps[0].runs["h9"]?.points[1] = T.p(2, 0.5)
        let open = try opened(tactic)
        #expect(steps(open)[1].positions["a5"] == T.p(0, 1))
        #expect(steps(open)[0].arrows[0].points[1] == T.p(1, 0))
        #expect(steps(open)[0].runs["h9"]?.points[1] == T.p(1, 0.5))
    }

    // MARK: sides and pitch

    @Test func unknownOrMissingColourTakesTheSideDefault() throws {
        var data = try T.patched(T.small(), replacing: "\"colour\":\"blue\"", with: "\"colour\":\"teal\"")
        var open = try TacticFormat.decode(data)
        #expect(open.sides.map(\.colour) == [.blue, .orange])

        let text = try T.json(T.small())
            .replacingOccurrences(of: "\"colour\":\"orange\",", with: "")
            .replacingOccurrences(of: "\"colour\":\"blue\",", with: "\"colour\":7,")
        data = Data(text.utf8)
        open = try TacticFormat.decode(data)
        #expect(open.sides.map(\.colour) == [.blue, .orange])
    }

    /// Judgement call: the table is silent on side order; reading sorts them home, then away.
    @Test func sidesAreOrderedHomeThenAway() throws {
        var tactic = T.small()
        tactic.sides.reverse()
        #expect(try opened(tactic).sides.map(\.id) == [.home, .away])
    }

    /// Judgement call: `pitch.style` is cosmetic and not in the table, so an unknown one repairs to stripes.
    @Test func unknownPitchStyleBecomesStripes() throws {
        let data = try T.patched(T.small(), replacing: "\"style\":\"plain\"", with: "\"style\":\"chequered\"")
        #expect(try TacticFormat.decode(data).pitch == Pitch(kind: .full, style: .stripes))
    }

    // MARK: tokens

    @Test func emptyBoardIsValid() throws {
        var tactic = T.small()
        tactic.tokens = []
        tactic.phases[0].steps = [Step(id: "s1")]
        #expect(try opened(tactic) == tactic)
    }

    @Test(arguments: [(150, 99), (100, 99), (-3, 0), (0, 0), (99, 99), (7, 7)])
    func numberIsClamped(written: Int, read: Int) throws {
        var tactic = T.small()
        tactic.tokens[0].number = written
        #expect(try opened(tactic).tokens[0].number == read)
    }

    @Test(arguments: ["7.5", "1e20", "-1e20"])
    func nonIntegerNumberIsRefused(written: String) throws {
        // An in-range integer is clamped; anything that isn't an integer refuses (FORMAT tokens[].number, D-45).
        var tactic = T.small()
        tactic.tokens[0].number = 42
        let data = try T.patched(tactic, replacing: "\"number\":42", with: "\"number\":\(written)")
        #expect(T.refusal(data) == .unreadable)
    }

    @Test func longNameIsTruncatedToTwentyFourCharacters() throws {
        var tactic = T.small()
        tactic.tokens[1].name = String(repeating: "Ade", count: 10)  // 30 characters
        tactic.tokens[2].name = "Ọlálékan Adébáyọ̀-Ọ̀ṣúndáre"  // combining marks count as one character each
        let open = try opened(tactic)
        #expect(open.tokens[1].name == String(repeating: "Ade", count: 8))
        #expect(open.tokens[2].name?.count == 24)
        #expect(open.tokens[2].name == String("Ọlálékan Adébáyọ̀-Ọ̀ṣúndáre".prefix(24)))
    }

    @Test func unknownRoleIsDroppedAndKnownRoleKept() throws {
        var tactic = T.small()
        tactic.tokens[0].roleID = "libero-supreme"
        let open = try opened(tactic)
        #expect(open.tokens[0].roleID == nil)
        #expect(open.tokens[1].roleID == "striker")
    }

    @Test func bundledRolesAreTheTwentyTwoPresets() throws {
        let roles = try #require(TacticFormat.bundledRoleIDs)
        #expect(roles.count == 22)
        #expect(roles.contains("goalkeeper") && roles.contains("free-role"))
    }

    // MARK: steps

    @Test(arguments: [(0.1, 0.3), (0.0, 0.3), (-4.0, 0.3), (9.0, 5.0), (5.0, 5.0), (2.5, 2.5)])
    func durationIsClamped(written: Double, read: Double) throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].duration = written
        #expect(try steps(opened(tactic))[1].duration == read)
    }

    @Test func missingDurationTakesTheDefault() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].duration = 1.234
        let data = try T.patched(tactic, replacing: "\"duration\":1.234,", with: "")
        #expect(try steps(TacticFormat.decode(data))[1].duration == 1.2)
    }

    @Test func longNoteIsTruncatedTo140Characters() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].note = String(repeating: "a", count: 200)
        #expect(try steps(opened(tactic))[1].note == String(repeating: "a", count: 140))
    }

    // MARK: positions

    @Test func tokenMissingFromAStepKeepsItsPreviousPosition() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].positions["a5"] = nil
        tactic.phases[0].steps[2].positions["a5"] = nil
        let open = try opened(tactic)
        #expect(steps(open)[1].positions["a5"] == T.p(0.5, 0.8))
        #expect(steps(open)[2].positions["a5"] == T.p(0.5, 0.8))
    }

    @Test func tokenMissingFromStepOneStartsOnTheCentreSpot() throws {
        var tactic = T.small()
        tactic.phases[0].steps[0].positions["h4"] = nil
        tactic.phases[0].steps[1].positions["h4"] = nil
        let open = try opened(tactic)
        #expect(steps(open)[0].positions["h4"] == .centre)
        #expect(steps(open)[1].positions["h4"] == .centre)
        #expect(steps(open)[2].positions["h4"] == T.p(0.4, 0.3))
    }

    @Test func positionKeysThatNameNoTokenAreIgnored() throws {
        var tactic = T.small()
        tactic.phases[0].steps[0].positions["ghost"] = T.p(0.1, 0.1)
        #expect(try opened(tactic) == T.small())
    }

    // MARK: runs

    @Test func runIsAnchoredToThisStepAndTheNext() throws {
        var tactic = T.small()
        tactic.phases[0].steps[0].runs["h9"] = Path(points: [T.p(0.1, 0.1), T.p(0.6, 0.7), T.p(0.9, 0.9)])
        let run = try #require(steps(opened(tactic))[0].runs["h9"])
        #expect(run.points == [T.p(0.5, 0.6), T.p(0.6, 0.7), T.p(0.55, 0.8)])
    }

    @Test func runAnchorsToACarriedPositionWhenTheNextStepOmitsTheToken() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].positions["h9"] = nil
        let run = try #require(steps(opened(tactic))[0].runs["h9"])
        #expect(run.points.first == T.p(0.5, 0.6))
        #expect(run.points.last == T.p(0.5, 0.6))
    }

    @Test func runOnTheLastStepIsDropped() throws {
        var tactic = T.small()
        tactic.phases[0].steps[2].runs["h4"] = Path(points: [T.p(0.4, 0.3), T.p(0.4, 0.5)])
        #expect(try steps(opened(tactic))[2].runs.isEmpty)
    }

    @Test func runForAnUnknownTokenIsDropped() throws {
        var tactic = T.small()
        tactic.phases[0].steps[1].runs["ghost"] = Path(points: [T.p(0.4, 0.3), T.p(0.4, 0.5)])
        #expect(try steps(opened(tactic))[1].runs.isEmpty)
    }

    // MARK: Unknown keys

    @Test func unknownKeysAreIgnoredOnRead() throws {
        let text = try T.json(T.small())
            .replacingOccurrences(of: "\"title\":\"Small\"", with: "\"title\":\"Small\",\"extra\":[1,{\"a\":null}]")
            .replacingOccurrences(of: "\"kind\":\"ball\"", with: "\"kind\":\"ball\",\"spin\":3")
            .replacingOccurrences(of: "\"id\":\"s2\"", with: "\"id\":\"s2\",\"camera\":\"wide\"")
        #expect(try TacticFormat.decode(Data(text.utf8)) == T.small())
    }

    @Test func malformedAppInfoIsDroppedNotRefused() throws {
        let data = try T.patched(T.small(), replacing: "\"app\":{\"createdWith\":\"TestTactics\"}", with: "\"app\":\"x\"")
        let open = try TacticFormat.decode(data)
        #expect(open.app == nil)
        #expect(open.tokens == T.small().tokens)
    }
}
