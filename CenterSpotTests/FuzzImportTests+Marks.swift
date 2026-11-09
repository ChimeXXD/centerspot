import Foundation
import Testing
@testable import CenterSpot

/// D-65's marks under the same fuzz as the rest of the file (D6-3): the hero's step 4 has a zone, a line, rings and
/// heat, so these cases bend only that subtree, where generated cases over the whole file rarely land.
extension FuzzImportTests {
    @Test func structuralDamageToMarks() throws {
        var mutator = try FuzzMutator(fixture: Fixtures.data("overlap-left"), seed: Self.seed("overlap-left marks", 3),
                                      focus: "marks")
        let cases = (0..<600).map { mutator.treeCase($0) }
        try Self.expectSafe(cases, from: "overlap-left marks")
    }

    /// Every field of every mark swapped for every wrong type, and every number for every hostile number.
    @Test func everyMarkFieldTakesEveryWrongType() throws {
        let tree = try FuzzJSON(data: Fixtures.data("overlap-left"))
        let paths = tree.paths(under: "marks")
        #expect(paths.count > 20, "the hero's marks are in the tree: \(paths.count) nodes")
        var cases: [FuzzMutator.Case] = []
        for path in paths {
            let field = tree.key(at: path) ?? "·"
            for value in FuzzMutator.wrongTypes {
                cases.append(.init(name: "\(path) \(field) = \(value.text)", data: tree.replacing(at: path) { _ in value }.data))
            }
            guard case .number? = tree.node(at: path) else { continue }
            for literal in FuzzMutator.hostileNumbers {
                cases.append(.init(name: "\(path) \(field) = \(literal)", data: tree.replacing(at: path) { _ in .number(literal) }.data))
            }
        }
        try Self.expectSafe(cases, from: "overlap-left")
    }

    /// Hand-written: limits, both glow shapes at once, every id the same, players of both sides, huge boxes.
    @Test func hostileMarks() throws {
        let hero = try Fixtures.tactic("overlap-left")
        func on(_ marks: Marks) throws -> Data { try TestTactics.data(TestTactics.changing(hero, step: 3) { $0.marks = marks }) }
        let everyone = hero.tokens.map(\.id)
        let zone = Zone(id: "m", x: 1e300, y: -1e300, w: -1e300, h: 1e300)
        var cases: [FuzzMutator.Case] = [
            .init(name: "13 marks", data: try on(Marks(glows: (0..<13).map { Glow(id: "g\($0)", target: .token("h3")) }))),
            .init(name: "12 marks, one id", data: try on(Marks(glows: (0..<12).map { _ in Glow(id: "m", target: .token("h3")) }))),
            .init(name: "line of everyone", data: try on(Marks(lines: [ShapeLine(id: "l", tokens: Array(everyone.prefix(11)))]))),
            .init(name: "line of 12", data: try on(Marks(lines: [ShapeLine(id: "l", tokens: Array(everyone.prefix(12)))]))),
            .init(name: "huge zone", data: try on(Marks(zones: [zone]))),
            .init(name: "same id every kind", data: try on(Marks(zones: [zone], lines: [ShapeLine(id: "m", tokens: ["h3", "h9"])],
                                                                 glows: [Glow(id: "m", target: .token("h9"))]))),
        ]
        let text = try #require(String(data: try on(Marks(glows: [Glow(id: "g", target: .token("h3"))])), encoding: .utf8))
        for (name, replacement) in [
            ("glow with token and spot", #"{"id":"g","token":"h3","x":0.5,"y":0.5,"r":0.1}"#),
            ("glow with a numeric token", #"{"id":"g","token":3}"#),
            ("glow with x only", #"{"id":"g","x":0.5}"#),
            ("marks as a list", nil),
        ] {
            let patched = replacement.map { text.replacingOccurrences(of: #"{"id":"g","token":"h3"}"#, with: $0) }
                ?? text.replacingOccurrences(of: #""marks":{"glows":[{"id":"g","token":"h3"}]}"#, with: #""marks":[]"#)
            #expect(patched != text, "\(name) patched nothing")
            cases.append(.init(name: name, data: Data(patched.utf8)))
        }
        try Self.expectSafe(cases, from: "overlap-left hostile marks")
    }
}
