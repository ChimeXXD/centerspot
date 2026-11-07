import Foundation
import Testing
@testable import Agmen

/// D-56: a `.tactic` from AirDrop, WhatsApp or Files is checked by `TacticFormat` and copied in; the example move is
/// added on the first launch only.
struct TacticLibraryImportTests {
    // MARK: Import

    @Test func importCopiesAValidFileIn() throws {
        let (library, folder) = try TacticLibraryTests.make()
        let external = try outside(Fixtures.data("overlap-left"), name: "shared.tactic")
        let url = try library.importFile(from: external)
        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(url.lastPathComponent == "Overlap down the left.tactic")
        #expect(try library.load(url) == Fixtures.tactic("overlap-left"))
        #expect(FileManager.default.fileExists(atPath: external.path), "the original stays where it was")
    }

    @Test func importingTheSameTacticTwiceGivesTheCopyANewID() throws {
        let (library, _) = try TacticLibraryTests.make()
        let external = try outside(Fixtures.data("overlap-left"), name: "shared.tactic")
        let first = try library.importFile(from: external)
        let second = try library.importFile(from: external)
        #expect(second.lastPathComponent == "Overlap down the left 2.tactic")
        #expect(try library.load(first).id != library.load(second).id)
        #expect(try library.load(first).id == Fixtures.tactic("overlap-left").id)
    }

    @Test func importRefusesAnOversizedFile() throws {
        let (library, folder) = try TacticLibraryTests.make()
        var big = try Fixtures.data("overlap-left")
        big.append(Data(repeating: 0x20, count: TacticFormat.maxByteCount))
        let external = try outside(big, name: "big.tactic")
        #expect(throws: TacticFormatError.unreadable) { try library.importFile(from: external) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func importRefusesANewerVersionWithItsMessage() throws {
        let (library, _) = try TacticLibraryTests.make()
        let external = try outside(Data(#"{"schemaVersion": 2}"#.utf8), name: "future.tactic")
        let error = #expect(throws: TacticFormatError.self) { try library.importFile(from: external) }
        #expect(error?.message == "Made with a newer version of Agmen.")
    }

    @Test func importRefusesGarbageAndAMissingFile() throws {
        let (library, folder) = try TacticLibraryTests.make()
        let garbage = try outside(Data("{".utf8), name: "garbage.tactic")
        #expect(throws: TacticFormatError.unreadable) { try library.importFile(from: garbage) }
        let missing = garbage.deletingLastPathComponent().appendingPathComponent("missing.tactic")
        #expect(throws: TacticFormatError.unreadable) { try library.importFile(from: missing) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func openingAFileAlreadyInTheLibraryDoesNotCopyIt() throws {
        let (library, folder) = try TacticLibraryTests.make()
        let url = try library.create()
        #expect(try library.importFile(from: url).standardizedFileURL == url.standardizedFileURL)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).count == 1)
    }

    @Test func anInboxCopyIsMovedIntoTheLibrary() throws {
        let (library, folder) = try TacticLibraryTests.make()
        let inbox = folder.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let delivered = inbox.appendingPathComponent("shared.tactic")
        try Fixtures.data("overlap-left").write(to: delivered)
        let url = try library.importFile(from: delivered)
        #expect(url.lastPathComponent == "Overlap down the left.tactic")
        #expect(!FileManager.default.fileExists(atPath: delivered.path), "the Inbox copy is cleaned up")
    }

    // MARK: First launch

    @Test func firstLaunchAddsTheExampleOnce() throws {
        let (library, _) = try TacticLibraryTests.make()
        library.seedExampleIfFirstLaunch()
        library.seedExampleIfFirstLaunch()
        let entries = try library.entries().entries
        #expect(entries.map(\.tactic.title) == ["Overlap down the left"])
        #expect(entries.first?.url.lastPathComponent == "Overlap down the left.tactic")
        #expect(entries.first?.tactic.phases.first?.steps.count == 5)
    }

    @Test func aDeletedExampleDoesNotComeBack() throws {
        let (library, _) = try TacticLibraryTests.make()
        library.seedExampleIfFirstLaunch()
        try library.delete(try #require(library.entries().entries.first).url)
        library.seedExampleIfFirstLaunch()
        #expect(try library.entries().entries.isEmpty)
    }

    @Test func aMissingExampleIsTriedAgainNextLaunch() throws {
        let (base, folder) = try TacticLibraryTests.make()
        let broken = TacticLibrary(folder: folder, defaults: base.defaults, exampleURL: folder.appendingPathComponent("gone.tactic"))
        broken.seedExampleIfFirstLaunch()
        #expect(try broken.entries().entries.isEmpty)
        base.seedExampleIfFirstLaunch()
        #expect(try base.entries().entries.count == 1)
    }

    // MARK: Helpers

    /// Writes `data` to a temporary folder outside the library, like a file from Files or AirDrop.
    private func outside(_ data: Data, name: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("external-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }
}
