import Foundation
import Testing
@testable import Agmen

/// Hand-written hostile files: each must pass the same checks as the generated ones and, where FORMAT.md decides the
/// outcome, end the way it says.
extension FuzzImportTests {
    typealias T = TestTactics

    enum Expected: Sendable, Equatable {
        case refuse(TacticFormatError)
        case open
        /// FORMAT.md doesn't decide (a BOM, UTF-16, a depth limit); only "no crash, plain error or valid" applies.
        case either
    }

    struct Hostile: Sendable {
        let name: String
        let data: Data
        let expected: Expected
    }

    @Test func handWrittenHostileFiles() throws {
        let (library, _) = try TacticLibraryTests.make()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("hostile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let external = outside.appendingPathComponent("shared.tactic")

        let cases = try Self.hostileCases()
        var problems: [String] = []
        for hostile in cases {
            let found = Self.check(hostile.data, library: library, external: external)
            problems += found.problems.map { "\(hostile.name): \($0)" }
            let outcome: Expected
            do throws(TacticFormatError) {
                _ = try TacticFormat.decode(hostile.data)
                outcome = .open
            } catch {
                outcome = .refuse(error)
            }
            if hostile.expected != .either, outcome != hostile.expected {
                problems.append("\(hostile.name): expected \(hostile.expected), got \(outcome)")
            }
        }
        #expect(problems.isEmpty, "\(problems.count) problems in \(cases.count) cases:\n\(problems.joined(separator: "\n"))")
    }

    // MARK: The cases

    static func hostileCases() throws -> [Hostile] {
        let small = try T.json(T.small())
        let smallData = Data(small.utf8)
        func patched(_ target: String, _ replacement: String) -> Data {
            Data(small.replacingOccurrences(of: target, with: replacement).utf8)
        }
        func bytes(_ target: String, _ replacement: [UInt8]) -> Data {
            let parts = small.components(separatedBy: target)
            return Data(parts[0].utf8) + Data(replacement) + Data(parts.dropFirst().joined(separator: target).utf8)
        }
        func tactic(_ change: (inout Tactic) -> Void) throws -> Data {
            var tactic = T.small()
            change(&tactic)
            return try T.data(tactic)
        }
        func spaces(_ count: Int) -> Data { Data(repeating: 0x20, count: count) }

        var cases: [Hostile] = [
            // Not a tactic at all.
            .init(name: "empty file", data: Data(), expected: .refuse(.unreadable)),
            .init(name: "whitespace only", data: Data(String(repeating: " \n\t\r", count: 500).utf8), expected: .refuse(.unreadable)),
            .init(name: "null", data: Data("null".utf8), expected: .refuse(.unreadable)),
            .init(name: "empty object", data: Data("{}".utf8), expected: .refuse(.unreadable)),
            .init(name: "top-level array", data: Data("[\(small)]".utf8), expected: .refuse(.unreadable)),
            .init(name: "a number", data: Data("1".utf8), expected: .refuse(.unreadable)),
            .init(name: "a string", data: Data("\"tactic\"".utf8), expected: .refuse(.unreadable)),
            .init(name: "trailing garbage", data: smallData + Data("}".utf8), expected: .refuse(.unreadable)),

            // Encodings.
            .init(name: "UTF-8 BOM", data: Data([0xEF, 0xBB, 0xBF]) + smallData, expected: .either),
            .init(name: "UTF-16LE with BOM", data: try #require(small.data(using: .utf16LittleEndian)).withBOM([0xFF, 0xFE]), expected: .either),
            .init(name: "UTF-16BE without BOM", data: try #require(small.data(using: .utf16BigEndian)), expected: .either),
            .init(name: "UTF-32LE", data: try #require(small.data(using: .utf32LittleEndian)), expected: .either),
            .init(name: "invalid UTF-8 in the title", data: bytes("Small", [0x53, 0xFF, 0x6D]), expected: .either),
            .init(name: "overlong UTF-8 slash", data: bytes("Small", [0xC0, 0xAF]), expected: .either),
            .init(name: "lone surrogate escape", data: patched("\"Small\"", #""\ud800""#), expected: .either),
            .init(name: "NUL in the title", data: patched("\"Small\"", #""Sm\u0000all""#), expected: .open),
            .init(name: "control characters only", data: patched("\"Small\"", #""\u0001\u0002\n\t""#), expected: .open),
            .init(name: "title is a path", data: patched("\"Small\"", #""../../etc/passwd""#), expected: .open),
            .init(name: "title is a dot", data: patched("\"Small\"", #"".""#), expected: .open),
            .init(name: "title is an emoji family", data: patched("\"Small\"", "\"" + String(repeating: "👨‍👩‍👧‍👦", count: 300) + "\""), expected: .open),

            // schemaVersion.
            .init(name: "schemaVersion 0", data: patched("\"schemaVersion\":1", "\"schemaVersion\":0"), expected: .refuse(.unreadable)),
            .init(name: "schemaVersion 2", data: patched("\"schemaVersion\":1", "\"schemaVersion\":2"), expected: .refuse(.newerVersion)),
            .init(name: "schemaVersion 999", data: patched("\"schemaVersion\":1", "\"schemaVersion\":999"), expected: .refuse(.newerVersion)),
            .init(name: "schemaVersion \"1\"", data: patched("\"schemaVersion\":1", "\"schemaVersion\":\"1\""), expected: .refuse(.unreadable)),
            .init(name: "schemaVersion -0", data: patched("\"schemaVersion\":1", "\"schemaVersion\":-0"), expected: .refuse(.unreadable)),
            .init(name: "schemaVersion 1e0", data: patched("\"schemaVersion\":1", "\"schemaVersion\":1e0"), expected: .either),
            .init(name: "schemaVersion twice, 1 then 2", data: patched("\"schemaVersion\":1", "\"schemaVersion\":1,\"schemaVersion\":2"), expected: .either),

            // Limits.
            .init(name: "31 tokens", data: try tactic { $0.tokens = (0..<31).map { Token(id: "c\($0)", kind: .cone) } }, expected: .refuse(.unreadable)),
            .init(name: "41 steps", data: try tactic { $0.phases[0].steps = (1...41).map { Step(id: "s\($0)") } }, expected: .refuse(.unreadable)),
            .init(name: "201 run points", data: try tactic { $0.phases[0].steps[0].runs["h9"] = Path(points: Array(repeating: .centre, count: 201)) }, expected: .refuse(.unreadable)),
            .init(name: "201 arrow points", data: try tactic { $0.phases[0].steps[0].arrows[0].points = Array(repeating: .centre, count: 201) }, expected: .refuse(.unreadable)),
            .init(name: "duplicate token ids", data: try tactic { $0.tokens[1].id = "h4" }, expected: .refuse(.unreadable)),
            .init(name: "run for an unknown token", data: try tactic { $0.phases[0].steps[0].runs["ghost"] = Path(points: [.centre, .centre]) }, expected: .open),
            .init(name: "run on the last step", data: try tactic { $0.phases[0].steps[2].runs["h4"] = Path(points: [.centre, .centre]) }, expected: .open),
            .init(name: "duplicate key, last wins or first", data: patched("\"title\":\"Small\"", "\"title\":\"A\",\"title\":\"B\""), expected: .open),

            // Size.
            .init(name: "exactly 256 KB", data: smallData + spaces(TacticFormat.maxByteCount - smallData.count), expected: .open),
            .init(name: "256 KB + 1", data: smallData + spaces(TacticFormat.maxByteCount + 1 - smallData.count), expected: .refuse(.unreadable)),
            .init(name: "1 MB title", data: patched("\"Small\"", "\"" + String(repeating: "a", count: 1_000_000) + "\""), expected: .refuse(.unreadable)),
            .init(name: "250 KB title", data: patched("\"Small\"", "\"" + String(repeating: "é", count: 120_000) + "\""), expected: .open),
            .init(name: "200 KB note", data: patched("\"Ball over the top\"", "\"" + String(repeating: "n", count: 200_000) + "\""), expected: .open),
            .init(name: "200 KB name", data: patched("\"Tolu\"", "\"" + String(repeating: "T", count: 200_000) + "\""), expected: .open),
            .init(name: "one 100 KB grapheme as the note", data: patched("\"Ball over the top\"", "\"e" + String(repeating: "\u{0301}", count: 50_000) + "\""), expected: .open),
            .init(name: "long token ids filled into every step", data: try longIDTactic(length: 2_000), expected: .either),
            .init(name: "missing positions filled near the cap", data: try paddedEmptyPositions(), expected: .either),

            // Numbers.
            .init(name: "duration 1e308", data: patched("\"duration\":1.2", "\"duration\":1e308"), expected: .open),
            .init(name: "duration -0", data: patched("\"duration\":1.2", "\"duration\":-0"), expected: .open),
            .init(name: "duration as a string", data: patched("\"duration\":1.2", "\"duration\":\"1.2\""), expected: .refuse(.unreadable)),
            .init(name: "x 1e308", data: patched("\"x\":0.4", "\"x\":1e308"), expected: .open),
            .init(name: "x -0", data: patched("\"x\":0.4", "\"x\":-0"), expected: .open),
            .init(name: "x 1e-400", data: patched("\"x\":0.4", "\"x\":1e-400"), expected: .either),
            .init(name: "x as a string", data: patched("\"x\":0.4", "\"x\":\"0.4\""), expected: .refuse(.unreadable)),
            .init(name: "x NaN", data: patched("\"x\":0.4", "\"x\":NaN"), expected: .refuse(.unreadable)),
            .init(name: "number 1e308", data: patched("\"number\":4", "\"number\":1e308"), expected: .refuse(.unreadable)),
            .init(name: "number -0", data: patched("\"number\":4", "\"number\":-0"), expected: .either),
            .init(name: "number past Int64", data: patched("\"number\":4", "\"number\":9223372036854775808"), expected: .refuse(.unreadable)),
        ]

        // Nesting 10,000 deep, in an unknown key and in place of a real field.
        for (open, close) in [("[", "]"), ("{\"a\":", "}")] {
            let deep = String(repeating: open, count: 10_000) + "1" + String(repeating: close, count: 10_000)
            cases.append(.init(name: "nested \(open)×10000 in an unknown key", data: patched("\"schemaVersion\":1", "\"schemaVersion\":1,\"deep\":\(deep)"), expected: .either))
            cases.append(.init(name: "nested \(open)×10000 as positions", data: patched("\"positions\":{", "\"positions\":\(deep),\"p\":{"), expected: .refuse(.unreadable)))
        }
        return cases
    }

    /// 30 tokens with `length`-character ids: small to read, but every step names every token once repaired.
    private static func longIDTactic(length: Int) throws -> Data {
        var tactic = T.small()
        tactic.tokens = (0..<30).map { Token(id: String(repeating: "x", count: length) + "\($0)", kind: .cone) }
        tactic.phases[0].steps = (1...40).map { Step(id: "s\($0)") }
        return try T.data(tactic)
    }

    /// 30 tokens and 40 steps with no positions, padded by its title to just under 256 KB: the repair that fills in
    /// every position makes the saved file bigger than the one that came in.
    private static func paddedEmptyPositions() throws -> Data {
        var tactic = T.small()
        tactic.tokens = (0..<30).map { Token(id: "c\($0)", kind: .cone) }
        tactic.phases[0].steps = (1...40).map { Step(id: "s\($0)") }
        tactic.title = ""
        let base = try T.data(tactic).count
        tactic.title = String(repeating: "t", count: TacticFormat.maxByteCount - base - 16)
        return try T.data(tactic)
    }
}

private extension Data {
    func withBOM(_ bom: [UInt8]) -> Data { Data(bom) + self }
}
