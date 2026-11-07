import Foundation
import Testing
@testable import Agmen

/// The draw tools' marks as pure edits (D-65, mockup draw.zone / draw.line / draw.glow / draw.mark.remove). Every edit
/// leaves a file that keeps docs/FORMAT.md's limits and reopens unchanged.
struct MarkEditsTests {
    typealias T = TestTactics

    private func expectValid(_ tactic: Tactic, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(FormatLimits.violations(of: tactic).isEmpty, "\(FormatLimits.violations(of: tactic))", sourceLocation: sourceLocation)
        #expect(try TacticFormat.decode(TacticFormat.encode(tactic)) == tactic, "reopens unchanged", sourceLocation: sourceLocation)
    }

    // MARK: Zones

    @Test func aDragMakesAZoneFromCornerToCorner() throws {
        var tactic = T.small()
        let result = MarkEdits.addZone(from: Point(x: 0.4, y: 0.8), to: Point(x: 0.1, y: 0.5), step: 1, in: &tactic)
        #expect(result == .added("z1"))
        let zone = try #require(try T.marks(1, of: tactic).zones.first)
        #expect(abs(zone.x - 0.1) < 1e-9 && abs(zone.y - 0.5) < 1e-9 && abs(zone.w - 0.3) < 1e-9 && abs(zone.h - 0.3) < 1e-9)
        #expect(zone.colour == .lime)
        try expectValid(tactic)
    }

    @Test func aDragUnderFourPercentEitherWayIsATap() {
        var tactic = T.small()
        #expect(MarkEdits.addZone(from: Point(x: 0.1, y: 0.5), to: Point(x: 0.139, y: 0.9), step: 0, in: &tactic) == .tooSmall)
        #expect(MarkEdits.addZone(from: Point(x: 0.1, y: 0.5), to: Point(x: 0.5, y: 0.539), step: 0, in: &tactic) == .tooSmall)
        #expect(tactic == T.small())
        #expect(MarkEdits.addZone(from: Point(x: 0.1, y: 0.5), to: Point(x: 0.14, y: 0.54), step: 0, in: &tactic) == .added("z1"))
    }

    @Test func aDragOffThePitchIsClamped() throws {
        var tactic = T.small()
        _ = MarkEdits.addZone(from: Point(x: -0.3, y: 1.4), to: Point(x: 0.3, y: 0.8), step: 0, in: &tactic)
        let zone = try #require(try T.marks(0, of: tactic).zones.first)
        #expect(zone.x == 0 && abs(zone.w - 0.3) < 1e-9 && abs(zone.y - 0.8) < 1e-9 && abs(zone.y + zone.h - 1) < 1e-9)
        try expectValid(tactic)
    }

    @Test func idsAreUnusedAcrossTheWholeTactic() {
        var tactic = T.small(marks: Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.1, w: 0.1, h: 0.1)]), onStep: 2)
        #expect(MarkEdits.addZone(from: .centre, to: Point(x: 0.7, y: 0.7), step: 0, in: &tactic) == .added("z2"))
        #expect(MarkEdits.addHeat(at: .centre, step: 0, in: &tactic) == .added("g1"))
        #expect(MarkEdits.addRings(on: "h9", step: 0, in: &tactic) == .added("g2"))
        #expect(MarkEdits.addLine(["h4", "h9"], step: 0, in: &tactic) == .added("l1"))
    }

    @Test func aStepHoldsTwelveMarks() throws {
        var tactic = T.small()
        for _ in 0..<12 { _ = MarkEdits.addHeat(at: .centre, step: 0, in: &tactic) }
        let full = tactic
        #expect(MarkEdits.addHeat(at: .centre, step: 0, in: &tactic) == .full)
        #expect(MarkEdits.addZone(from: .centre, to: Point(x: 0.9, y: 0.9), step: 0, in: &tactic) == .full)
        #expect(MarkEdits.addRings(on: "h4", step: 0, in: &tactic) == .full)
        #expect(MarkEdits.addLine(["h4", "h9"], step: 0, in: &tactic) == .full)
        #expect(tactic == full)
        try expectValid(tactic)
    }

    @Test func movingAZoneKeepsItsSizeAndStopsAtTheLines() throws {
        var tactic = T.small(marks: Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.5, w: 0.3, h: 0.2)]))
        MarkEdits.moveZone("z1", by: 0.2, 0.1, step: 0, in: &tactic)
        var zone = try #require(try T.marks(0, of: tactic).zones.first)
        #expect(abs(zone.x - 0.3) < 1e-9 && abs(zone.y - 0.6) < 1e-9 && zone.w == 0.3 && zone.h == 0.2)
        MarkEdits.moveZone("z1", by: 5, -5, step: 0, in: &tactic)
        zone = try #require(try T.marks(0, of: tactic).zones.first)
        #expect(abs(zone.x - 0.7) < 1e-9 && zone.y == 0 && zone.w == 0.3 && zone.h == 0.2)
        MarkEdits.moveZone("z1", by: .nan, 0, step: 0, in: &tactic)
        #expect(try #require(try T.marks(0, of: tactic).zones.first) == zone)
        try expectValid(tactic)
    }

    @Test(arguments: MarkEdits.Corner.allCases)
    func resizingMovesOnlyThatCorner(corner: MarkEdits.Corner) throws {
        var tactic = T.small(marks: Marks(zones: [Zone(id: "z1", x: 0.2, y: 0.4, w: 0.4, h: 0.2)]))
        MarkEdits.resizeZone("z1", corner: corner, to: Point(x: 0.1, y: 0.9), step: 0, in: &tactic)
        let zone = try #require(try T.marks(0, of: tactic).zones.first)
        let (left, right, bottom, top) = (zone.x, zone.x + zone.w, zone.y, zone.y + zone.h)
        switch corner {
        case .topLeft: #expect(abs(left - 0.1) < 1e-9 && abs(right - 0.6) < 1e-9 && abs(bottom - 0.4) < 1e-9 && abs(top - 0.9) < 1e-9)
        case .topRight: #expect(abs(left - 0.2) < 1e-9 && abs(right - 0.24) < 1e-9 && abs(top - 0.9) < 1e-9, "min width")
        case .bottomLeft: #expect(abs(left - 0.1) < 1e-9 && abs(bottom - 0.56) < 1e-9 && abs(top - 0.6) < 1e-9, "min height")
        case .bottomRight: #expect(abs(right - 0.24) < 1e-9 && abs(bottom - 0.56) < 1e-9, "both at the minimum")
        }
        try expectValid(tactic)
    }

    @Test func resizingPastThePitchIsClamped() throws {
        var tactic = T.small(marks: Marks(zones: [Zone(id: "z1", x: 0.2, y: 0.4, w: 0.4, h: 0.2)]))
        MarkEdits.resizeZone("z1", corner: .topRight, to: Point(x: 3, y: 3), step: 0, in: &tactic)
        let zone = try #require(try T.marks(0, of: tactic).zones.first)
        #expect(abs(zone.x + zone.w - 1) < 1e-9 && abs(zone.y + zone.h - 1) < 1e-9)
        try expectValid(tactic)
    }

    // MARK: Lines

    @Test func aLineJoinsPlayersOfOneSideInOrder() throws {
        var tactic = T.small()
        #expect(MarkEdits.addLine(["h9", "a5", "h4", "ball"], step: 0, in: &tactic) == .added("l1"))
        #expect(try T.marks(0, of: tactic).lines == [ShapeLine(id: "l1", tokens: ["h9", "h4"])])
        try expectValid(tactic)
    }

    @Test func aLineOfOneIsNotAdded() {
        var tactic = T.small()
        #expect(MarkEdits.addLine(["h9"], step: 0, in: &tactic) == .invalid)
        #expect(MarkEdits.addLine(["h9", "a5"], step: 0, in: &tactic) == .invalid)
        #expect(tactic == T.small())
    }

    @Test func tappingOutALine() {
        let tactic = T.small()
        var draft = LineDraft()
        #expect(draft.tap(nil, in: tactic) == .ignored, "the grass does nothing")
        #expect(draft.tap("ball", in: tactic) == .ignored)
        #expect(draft.tap("h4", in: tactic) == .started)
        #expect(!draft.isComplete)
        #expect(draft.tap("a5", in: tactic) == .otherSide, "One side per line")
        #expect(draft.tap("h9", in: tactic) == .added)
        #expect(draft.tap("h4", in: tactic) == .ignored, "already in the line")
        #expect(draft.tap("h9", in: tactic) == .finished, "the last player again")
        #expect(draft.tokens == ["h4", "h9"] && draft.isComplete)
    }

    @Test func aLineOfElevenFinishesItself() {
        var tactic = T.small()
        let ids = (0..<11).compactMap { _ in TacticEdits.addToken(.ourPlayer, in: &tactic) }
        var draft = LineDraft()
        let outcomes = ids.map { draft.tap($0, in: tactic) }
        #expect(outcomes.last == .finished)
        #expect(draft.tokens.count == ShapeLine.maxTokens)
    }

    // MARK: Glows

    @Test func ringsGoUnderAPlayerOnce() throws {
        var tactic = T.small()
        #expect(MarkEdits.addRings(on: "a5", step: 1, in: &tactic) == .added("g1"))
        #expect(MarkEdits.addRings(on: "a5", step: 1, in: &tactic) == .existing("g1"), "a second tap selects it")
        #expect(MarkEdits.addRings(on: "ball", step: 1, in: &tactic) == .invalid)
        #expect(try T.marks(1, of: tactic).glows == [Glow(id: "g1", target: .token("a5"))])
        try expectValid(tactic)
    }

    @Test func heatGoesOnTheGrassAtTheDefaultSize() throws {
        var tactic = T.small()
        #expect(MarkEdits.addHeat(at: Point(x: 0.5, y: 1.3), step: 2, in: &tactic) == .added("g1"))
        #expect(try T.marks(2, of: tactic).glows == [Glow(id: "g1", target: .spot(Point(x: 0.5, y: 1), radius: Glow.defaultRadius))])
        try expectValid(tactic)
    }

    // MARK: Removing, and edits elsewhere

    @Test func removeTakesOneMarkOffOneStep() {
        var tactic = T.small(marks: T.someMarks, onStep: 1)
        #expect(MarkEdits.remove("l1", step: 1, in: &tactic))
        #expect(!MarkEdits.remove("l1", step: 1, in: &tactic))
        #expect(!MarkEdits.remove("z1", step: 0, in: &tactic), "not on that step")
        #expect((try? T.marks(1, of: tactic).ids) == ["z1", "g1", "g2"])
    }

    @Test func badStepsChangeNothing() {
        var tactic = T.small()
        #expect(MarkEdits.addHeat(at: .centre, step: 3, in: &tactic) == .invalid)
        #expect(MarkEdits.addZone(from: .centre, to: Point(x: 0.9, y: 0.9), step: -1, in: &tactic) == .invalid)
        MarkEdits.moveZone("z1", by: 0.1, 0.1, step: 9, in: &tactic)
        #expect(tactic == T.small())
    }

    @Test func removingAPlayerTakesThemOutOfEveryMark() throws {
        var tactic = T.small(marks: T.someMarks, onStep: 1)
        TacticEdits.deleteToken("h9", in: &tactic)
        let marks = try T.marks(1, of: tactic)
        #expect(marks.lines.isEmpty, "a line of one is dropped")
        #expect(marks.glows.map(\.id) == ["g2"], "their rings go; heat stays")
        try expectValid(tactic)
    }

    @Test func aPlayerWhoChangesSideLeavesTheLine() throws {
        let three = Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9", "h4b"])])
        var tactic = T.small()
        tactic.tokens.append(Token(id: "h4b", kind: .player, side: .home, number: 14))
        tactic = T.changing(tactic, step: 0) { $0.marks = three; $0.positions["h4b"] = .centre }
        tactic = T.changing(tactic, step: 1) { $0.positions["h4b"] = .centre }
        tactic = T.changing(tactic, step: 2) { $0.positions["h4b"] = .centre }
        TacticEdits.setSide(.away, token: "h9", in: &tactic)
        #expect(try T.marks(0, of: tactic).lines == [ShapeLine(id: "l1", tokens: ["h4", "h4b"])])
        try expectValid(tactic)
    }

    @Test func theFirstPlayerOfALineChangingSideLeavesTheRestOfIt() throws {
        let three = Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9", "h4b"])])
        var tactic = T.small()
        tactic.tokens.append(Token(id: "h4b", kind: .player, side: .home, number: 14))
        tactic = T.changing(tactic, step: 0) { $0.marks = three; $0.positions["h4b"] = .centre }
        tactic = T.changing(tactic, step: 1) { $0.positions["h4b"] = .centre }
        tactic = T.changing(tactic, step: 2) { $0.positions["h4b"] = .centre }
        TacticEdits.setSide(.away, token: "h4", in: &tactic)
        #expect(try T.marks(0, of: tactic).lines == [ShapeLine(id: "l1", tokens: ["h9", "h4b"])])
        try expectValid(tactic)
    }

    @Test func aNewStepCarriesTheMarksOnWithTheirIDs() throws {
        var tactic = T.small(marks: T.someMarks, onStep: 1)
        let added = try #require(TacticEdits.addStep(after: 1, in: &tactic))
        #expect(try T.marks(added, of: tactic) == T.someMarks)
        #expect(try T.marks(1, of: tactic) == T.someMarks)
        // So they stay on, never fading, through the move into the copy.
        let rest = PlaybackTrack.restTimes(of: try #require(tactic.phases.first))
        let moving = try #require(rest[safe: 1]) + 0.6
        #expect(Timeline.state(at: moving, in: tactic).marks.allSatisfy { $0.opacity == 1 })
        try expectValid(tactic)
    }

    // MARK: Hitting and naming

    @Test func tapsFindTheTopMark() {
        let marks = Marks(zones: [Zone(id: "z1", x: 0.1, y: 0.1, w: 0.5, h: 0.5), Zone(id: "z2", x: 0.3, y: 0.3, w: 0.5, h: 0.5)],
                          lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])],
                          glows: [Glow(id: "g1", target: .spot(Point(x: 0.8, y: 0.9), radius: 0.1))])
        #expect(MarkHit.zone(at: Point(x: 0.4, y: 0.4), in: marks) == "z2")
        #expect(MarkHit.zone(at: Point(x: 0.2, y: 0.2), in: marks) == "z1")
        #expect(MarkHit.zone(at: Point(x: 0.95, y: 0.95), in: marks) == nil)
        #expect(MarkHit.heat(at: Point(x: 0.85, y: 0.9), in: marks, aspect: 105.0 / 68) == "g1")
        #expect(MarkHit.heat(at: Point(x: 0.8, y: 0.97), in: marks, aspect: 105.0 / 68) == nil, "0.07 of length is 0.108 wide")
        let positions = ["h4": Point(x: 0.2, y: 0.2), "h9": Point(x: 0.6, y: 0.2)]
        #expect(MarkHit.line(near: Point(x: 0.4, y: 0.21), in: marks, positions: positions, aspect: 1.5, reach: 0.03) == "l1")
        #expect(MarkHit.line(near: Point(x: 0.4, y: 0.3), in: marks, positions: positions, aspect: 1.5, reach: 0.03) == nil)
    }

    @Test func marksAreNamedInFootballWords() throws {
        let hero = try Fixtures.tactic("overlap-left")
        #expect(Placement.label(forMark: "z1", in: hero, stepIndex: 3) == "Zone 1, left wing, step 4")
        #expect(Placement.label(forMark: "l1", in: hero, stepIndex: 3) == "Line joining their 2, 5 and 4, step 4")
        #expect(Placement.label(forMark: "g1", in: hero, stepIndex: 3) == "Glow on number 3, step 4")
        #expect(Placement.label(forMark: "g2", in: hero, stepIndex: 3) == "Heat glow, penalty area, step 4")
        #expect(Placement.label(forMark: "z1", in: hero, stepIndex: 2) == nil, "not on step 3")
        #expect(Placement.rowLabel(forMark: "z1", in: hero, stepIndex: 3) == "Zone 1 · step 4")
        #expect(Placement.rowLabel(forMark: "g2", in: hero, stepIndex: 3) == "Glow 2 · step 4")
        let home = T.small(marks: Marks(lines: [ShapeLine(id: "l1", tokens: ["h4", "h9"])]))
        #expect(Placement.label(forMark: "l1", in: home, stepIndex: 0) == "Line joining 4 and 9, step 1")
    }
}
