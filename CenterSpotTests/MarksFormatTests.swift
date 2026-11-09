import Foundation
import Testing
@testable import CenterSpot

/// docs/FORMAT.md's rows for `steps[].marks` (D-65): an additive, optional part of format v1. Older files open
/// unchanged; limits refuse; cosmetic problems repair (D-27); everything round-trips.
struct MarksFormatTests {
    typealias T = TestTactics

    private func opened(_ tactic: Tactic) throws -> Tactic {
        try TacticFormat.decode(T.data(tactic))
    }

    private func reopened(_ data: Data) throws -> Tactic {
        try TacticFormat.decode(data)
    }

    // MARK: Additive

    @Test func aFileWithoutMarksOpensWithNoneAndWritesNone() throws {
        let tactic = try opened(T.small())
        #expect(try T.marks(0, of: tactic).isEmpty)
        let written = try #require(String(data: TacticFormat.encode(tactic), encoding: .utf8))
        #expect(!written.contains("marks"), "an older file saves as it was")
        #expect(written.contains("\"schemaVersion\" : 1"))
    }

    @Test func theHerosStepFourHasTheMockupsMarks() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let marks = try T.marks(3, of: hero)
        #expect(marks.zones == [Zone(id: "z1", x: 0.02, y: 0.52, w: 0.2, h: 0.34, colour: .lime)])
        #expect(marks.lines == [ShapeLine(id: "l1", tokens: ["a2", "a5", "a4"])])
        #expect(marks.glows == [Glow(id: "g1", target: .token("h3")),
                                Glow(id: "g2", target: .spot(Point(x: 0.5, y: 0.87), radius: 0.11))])
        for index in [0, 1, 2, 4] { #expect(try T.marks(index, of: hero).isEmpty, "step \(index + 1)") }
    }

    @Test func marksRoundTrip() throws {
        let first = try opened(T.small(marks: T.someMarks, onStep: 1))
        #expect(try T.marks(1, of: first) == T.someMarks)
        #expect(try reopened(TacticFormat.encode(first)) == first)
    }

    @Test func marksUseTheFormatsKeys() throws {
        let data = try TacticFormat.encode(opened(T.small(marks: T.someMarks)))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let step = try #require(((object["phases"] as? [[String: Any]])?.first?["steps"] as? [[String: Any]])?.first)
        let marks = try #require(step["marks"] as? [String: Any])
        #expect(Set(marks.keys) == ["zones", "lines", "glows"])
        let zone = try #require((marks["zones"] as? [[String: Any]])?.first)
        #expect(Set(zone.keys) == ["id", "x", "y", "w", "h", "colour"])
        let line = try #require((marks["lines"] as? [[String: Any]])?.first)
        #expect(Set(line.keys) == ["id", "tokens"])
        let glows = try #require(marks["glows"] as? [[String: Any]])
        #expect(glows.map { Set($0.keys) } == [["id", "token"], ["id", "x", "y", "r"]])
    }

    @Test func emptyListsAreLeftOut() throws {
        let zonesOnly = Marks(zones: T.someMarks.zones)
        let written = try #require(String(data: TacticFormat.encode(opened(T.small(marks: zonesOnly))), encoding: .utf8))
        #expect(written.contains("\"zones\""))
        #expect(!written.contains("\"lines\"") && !written.contains("\"glows\""))
    }

    // MARK: Refuse

    @Test func thirteenMarksAreRefused() throws {
        let zones = (1...13).map { Zone(id: "z\($0)", x: 0.1, y: 0.1, w: 0.1, h: 0.1) }
        #expect(T.refusal(try T.data(T.small(marks: Marks(zones: zones)))) == .unreadable)
        #expect(T.refusal(try T.data(T.small(marks: Marks(zones: Array(zones.prefix(12)))))) == nil)
    }

    @Test func theLimitCountsEveryKind() throws {
        let marks = Marks(zones: (1...5).map { Zone(id: "z\($0)", x: 0.1, y: 0.1, w: 0.1, h: 0.1) },
                          lines: (1...4).map { ShapeLine(id: "l\($0)", tokens: ["h4", "h9"]) },
                          glows: (1...4).map { Glow(id: "g\($0)", target: .spot(.centre, radius: 0.1)) })
        #expect(marks.count == 13)
        #expect(T.refusal(try T.data(T.small(marks: marks))) == .unreadable)
    }

    @Test func aLineNamingTwelvePlayersIsRefused() throws {
        let twelve = Marks(lines: [ShapeLine(id: "l1", tokens: Array(repeating: "h4", count: 12))])
        #expect(T.refusal(try T.data(T.small(marks: twelve))) == .unreadable)
        let eleven = Marks(lines: [ShapeLine(id: "l1", tokens: Array(repeating: "h4", count: 11))])
        #expect(T.refusal(try T.data(T.small(marks: eleven))) == nil)
    }

    @Test(arguments: ["NaN", "Infinity", "1e999", "-1e999", "\"0.5\"", "null"])
    func aZoneWithABadNumberIsRefused(literal: String) throws {
        let marks = Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.5, w: 0.321, h: 0.2)])
        let data = try T.patched(T.small(marks: marks), replacing: "0.321", with: literal)
        #expect(T.refusal(data) == .unreadable)
    }

    @Test(arguments: ["0.517", "0.623", "0.137"])
    func aHeatWithABadNumberIsRefused(value: String) throws {
        let marks = Marks(glows: [Glow(id: "g1", target: .spot(Point(x: 0.517, y: 0.623), radius: 0.137))])
        for literal in ["1e999", "NaN", "\"0.5\""] {
            let data = try T.patched(T.small(marks: marks), replacing: value, with: literal)
            #expect(T.refusal(data) == .unreadable, "\(value) → \(literal)")
        }
    }

    @Test func aGlowWithNeitherAPlayerNorASpotIsRefused() throws {
        let marks = Marks(glows: [Glow(id: "g1", target: .token("h9"))])
        let data = try T.patched(T.small(marks: marks), replacing: "\"token\":\"h9\"", with: "\"colour\":\"lime\"")
        #expect(T.refusal(data) == .unreadable)
    }

    @Test func aMarkWithoutAnIDIsRefused() throws {
        let data = try T.patched(T.small(marks: Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])])),
                                 replacing: "\"id\":\"l1\",", with: "")
        #expect(T.refusal(data) == .unreadable)
    }

    // MARK: Repair

    @Test func aZoneIsPulledOntoThePitchAndGrownToTheSmallestSize() throws {
        let marks = Marks(zones: [Zone(id: "z1", x: -0.5, y: 0.9, w: 0.3, h: 0.01)])
        let zone = try #require(try T.marks(0, of: opened(T.small(marks: marks))).zones.first)
        #expect(zone.x == 0 && abs(zone.w - Zone.minSize) < 1e-9, "\(zone)")
        #expect(abs(zone.y - 0.885) < 1e-9 && abs(zone.h - Zone.minSize) < 1e-9, "\(zone)")
    }

    @Test func aZoneDrawnBackwardsIsTurnedRoundAndCut() throws {
        let marks = Marks(zones: [Zone(id: "z1", x: 0.9, y: 0.5, w: -0.3, h: 0.8)])
        let zone = try #require(try T.marks(0, of: opened(T.small(marks: marks))).zones.first)
        #expect(abs(zone.x - 0.6) < 1e-9 && abs(zone.w - 0.3) < 1e-9, "\(zone)")
        #expect(zone.y == 0.5 && abs(zone.h - 0.5) < 1e-9, "cut at the goal line: \(zone)")
    }

    @Test func aZoneInsideThePitchReadsBackUnchanged() throws {
        let zone = Zone(id: "z1", x: 0.1 + 0.2, y: 1 - 0.04, w: 0.04, h: 0.04)
        #expect(zone.clamped == zone)
        #expect(zone.clamped.clamped == zone.clamped)
    }

    @Test func anUnknownZoneColourIsLime() throws {
        let marks = Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.5, w: 0.3, h: 0.2, colour: .sky)])
        let data = try T.patched(T.small(marks: marks), replacing: "\"colour\":\"sky\"", with: "\"colour\":\"tartan\"")
        #expect(try #require(try T.marks(0, of: reopened(data)).zones.first).colour == .lime)
        let missing = try T.patched(T.small(marks: marks), replacing: "\"colour\":\"sky\",", with: "")
        #expect(try #require(try T.marks(0, of: reopened(missing)).zones.first).colour == .lime)
    }

    @Test func heatIsClampedToThePitchAndItsSize() throws {
        let marks = Marks(glows: [Glow(id: "g1", target: .spot(Point(x: 0.5, y: 0.5), radius: 0.1))])
        let data = try T.patched(T.small(marks: marks), replacing: "\"r\":0.1,\"x\":0.5,\"y\":0.5", with: "\"r\":9,\"x\":-2,\"y\":1.5")
        let glow = try #require(try T.marks(0, of: reopened(data)).glows.first)
        #expect(glow.target == .spot(Point(x: 0, y: 1), radius: Glow.radiusRange.upperBound))
        let tiny = try T.patched(T.small(marks: marks), replacing: "\"r\":0.1", with: "\"r\":0")
        #expect(try #require(try T.marks(0, of: reopened(tiny)).glows.first).target == .spot(Point(x: 0.5, y: 0.5), radius: 0.03))
        let noRadius = try T.patched(T.small(marks: marks), replacing: "\"r\":0.1,", with: "")
        #expect(try #require(try T.marks(0, of: reopened(noRadius)).glows.first).target
                == .spot(Point(x: 0.5, y: 0.5), radius: Glow.defaultRadius))
    }

    @Test func aLineKeepsTheFirstPlayersSideEachOnce() throws {
        let line = ShapeLine(id: "l1", tokens: ["ghost", "ball", "h9", "a5", "h4", "h9", "h4"])
        let kept = try T.marks(0, of: opened(T.small(marks: Marks(lines: [line]))))
        #expect(kept.lines == [ShapeLine(id: "l1", tokens: ["h9", "h4"])])
    }

    @Test func aLineLeftWithOnePlayerIsDropped() throws {
        let lines = [ShapeLine(id: "l1", tokens: ["h9", "a5"]), ShapeLine(id: "l2", tokens: ["ghost", "h4"]),
                     ShapeLine(id: "l3", tokens: [])]
        #expect(try T.marks(0, of: opened(T.small(marks: Marks(lines: lines)))).lines.isEmpty)
    }

    @Test func ringsOnAnythingButAPlayerAreDropped() throws {
        let glows = [Glow(id: "g1", target: .token("ball")), Glow(id: "g2", target: .token("ghost")),
                     Glow(id: "g3", target: .token("a5"))]
        #expect(try T.marks(0, of: opened(T.small(marks: Marks(glows: glows)))).glows.map(\.id) == ["g3"])
    }

    @Test func aRepeatedIDDropsTheLaterMark() throws {
        let marks = Marks(zones: [Zone(id: "m", x: 0.1, y: 0.1, w: 0.1, h: 0.1)],
                          lines: [ShapeLine(id: "m", tokens: ["h4", "h9"]), ShapeLine(id: "n", tokens: ["h4", "h9"])],
                          glows: [Glow(id: "n", target: .token("h9")), Glow(id: "o", target: .token("h4"))])
        let kept = try T.marks(0, of: opened(T.small(marks: marks)))
        #expect(kept.ids == ["m", "n", "o"])
        #expect(kept.lines.map(\.id) == ["n"] && kept.glows.map(\.id) == ["o"])
    }

    @Test func anInvalidMarkDoesNotTakeItsIDFromAValidOne() throws {
        let marks = Marks(lines: [ShapeLine(id: "m", tokens: ["ghost"])], glows: [Glow(id: "m", target: .token("h9"))])
        #expect(try T.marks(0, of: opened(T.small(marks: marks))).ids == ["m"])
    }

    @Test func repairedMarksReopenUnchanged() throws {
        let marks = Marks(zones: [Zone(id: "z1", x: 0.97, y: -1, w: 0.5, h: 0.001)],
                          lines: [ShapeLine(id: "l1", tokens: ["a5", "h9", "a5"])],
                          glows: [Glow(id: "g1", target: .spot(Point(x: 0.999, y: 0.001), radius: 0.3))])
        let first = try opened(T.small(marks: marks))
        #expect(try reopened(TacticFormat.encode(first)) == first)
        #expect(FormatLimits.violations(of: first).isEmpty, "\(FormatLimits.violations(of: first))")
    }
}
