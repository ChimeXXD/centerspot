import Foundation
import Testing
@testable import CenterSpot

/// SPEC §9 / D6-3: hostile `.tactic` files never crash or hang the importer. Each case goes through both ways in,
/// `TacticFormat.decode` and `TacticLibrary.importFile`, and must end in a plain `TacticFormatError` or a tactic that
/// keeps every FORMAT limit and survives a save and reopen unchanged. Cases come from a fixed-seed mutator over every
/// fixture, so a failure names a case that the next run rebuilds exactly; `+Hostile` holds the hand-written ones.
@Suite(.timeLimit(.minutes(2)))
struct FuzzImportTests {
    /// Generous for one file on a busy simulator; a real hang never returns.
    static let caseDeadline = 3.0

    // MARK: Generated cases

    @Test(arguments: Fixtures.names)
    func byteDamage(fixture: String) throws {
        var mutator = try FuzzMutator(fixture: Fixtures.data(fixture), seed: Self.seed(fixture, 1))
        let cases = (0..<600).map { mutator.byteCase($0) }
        try Self.expectSafe(cases, from: fixture)
    }

    @Test(arguments: Fixtures.names)
    func structuralDamage(fixture: String) throws {
        var mutator = try FuzzMutator(fixture: Fixtures.data(fixture), seed: Self.seed(fixture, 2))
        let cases = (0..<600).map { mutator.treeCase($0) }
        try Self.expectSafe(cases, from: fixture)
    }

    @Test(arguments: Fixtures.names)
    func truncationAtManyOffsets(fixture: String) throws {
        let data = try Fixtures.data(fixture)
        let stride = max(1, data.count / 150)
        let offsets = Array(Swift.stride(from: 0, to: data.count, by: stride)) + [data.count - 1, data.count]
        let cases = offsets.map { FuzzMutator.Case(name: "truncate@\($0)", data: data.prefix($0)) }
        try Self.expectSafe(cases, from: fixture)
    }

    /// Every field of the small fixture swapped for every wrong type, and every number for every hostile number.
    @Test func everyFieldTakesEveryWrongType() throws {
        let tree = try FuzzJSON(data: Fixtures.data("five-a-side-long-ball"))
        var cases: [FuzzMutator.Case] = []
        for path in tree.paths {
            let field = tree.key(at: path) ?? "·"
            for value in FuzzMutator.wrongTypes {
                cases.append(.init(name: "\(path) \(field) = \(value.text)", data: tree.replacing(at: path) { _ in value }.data))
            }
            guard case .number? = tree.node(at: path) else { continue }
            for literal in FuzzMutator.hostileNumbers {
                cases.append(.init(name: "\(path) \(field) = \(literal)", data: tree.replacing(at: path) { _ in .number(literal) }.data))
            }
        }
        try Self.expectSafe(cases, from: "five-a-side-long-ball")
    }

    // MARK: Checking one case

    /// Runs every case through both ways in and fails once, listing the first problems found.
    static func expectSafe(_ cases: [FuzzMutator.Case], from fixture: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let (library, _) = try TacticLibraryTests.make()
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("fuzz-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let external = outside.appendingPathComponent("shared.tactic")

        var problems: [String] = []
        var opened = 0
        for fuzzCase in cases {
            let found = check(fuzzCase.data, library: library, external: external)
            if found.opened { opened += 1 }
            problems += found.problems.map { "\(fixture) \(fuzzCase.name): \($0)" }
        }
        #expect(
            problems.isEmpty,
            "\(problems.count) problems in \(cases.count) cases (\(opened) opened):\n\(problems.prefix(15).joined(separator: "\n"))",
            sourceLocation: sourceLocation
        )
    }

    /// One hostile file through `decode` and `importFile`. Returns whether it opened and every rule it broke.
    static func check(_ data: Data, library: TacticLibrary, external: URL) -> (opened: Bool, problems: [String]) {
        guard let decoded = Deadline.run(seconds: caseDeadline, { decodeResult(data) }) else {
            return (false, ["decode hung"])
        }
        var problems: [String] = []
        if case .success(let tactic) = decoded {
            problems += FormatLimits.violations(of: tactic)
            problems += roundTripProblems(tactic)
        }

        do {
            try data.write(to: external)
        } catch {
            return (false, problems + ["couldn't write the case: \(error)"])
        }
        let shared = SharedLibrary(library: library)
        guard let imported = Deadline.run(seconds: caseDeadline, { importResult(external, into: shared.library) }) else {
            return (false, problems + ["importFile hung"])
        }
        switch (decoded, imported) {
        case (.failure(let refused), .failure(let alsoRefused)):
            if refused != alsoRefused { problems.append("decode said \(refused), importFile said \(alsoRefused)") }
        case (.failure(let refused), .success):
            problems.append("decode refused (\(refused)) but importFile copied it in")
        case (.success, .failure(let refused)):
            problems.append("decode opened it but importFile refused (\(refused))")
        case (.success(let tactic), .success(let url)):
            do throws(TacticFormatError) {
                let reopened = try library.load(url)
                if reopened != tactic { problems.append("the imported copy reopens different") }
            } catch {
                problems.append("the imported copy doesn't reopen (\(error))")
            }
            try? FileManager.default.removeItem(at: url)
        }
        return (decoded.isSuccess, problems)
    }

    /// Save then reopen gives the same tactic, and the saved file stays under the size cap.
    static func roundTripProblems(_ tactic: Tactic) -> [String] {
        guard let encoded = try? TacticFormat.encode(tactic) else { return ["doesn't encode"] }
        do throws(TacticFormatError) {
            let reopened = try TacticFormat.decode(encoded)
            return reopened == tactic ? [] : ["re-encoding then decoding changes it"]
        } catch {
            return ["its own encoding (\(encoded.count) bytes) is refused: \(error)"]
        }
    }

    static func decodeResult(_ data: Data) -> Result<Tactic, TacticFormatError> {
        do throws(TacticFormatError) {
            return .success(try TacticFormat.decode(data))
        } catch {
            return .failure(error)
        }
    }

    static func importResult(_ url: URL, into library: TacticLibrary) -> Result<URL, TacticFormatError> {
        do throws(TacticFormatError) {
            return .success(try library.importFile(from: url))
        } catch {
            return .failure(error)
        }
    }

    static func seed(_ fixture: String, _ family: UInt64) -> UInt64 {
        fixture.utf8.reduce(family &* 0x5851_F42D_4C95_7F2D) { ($0 &* 31) &+ UInt64($1) }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
