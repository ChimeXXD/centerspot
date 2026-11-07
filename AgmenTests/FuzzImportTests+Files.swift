import Darwin
import Foundation
import Testing
@testable import Agmen

/// Things handed to `importFile` that aren't ordinary files: each is refused quickly with the plain error.
extension FuzzImportTests {
    private func folder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("odd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func importOutcome(_ url: URL, into library: TacticLibrary) -> Result<URL, TacticFormatError>? {
        let shared = SharedLibrary(library: library)
        return Deadline.run(seconds: Self.caseDeadline) { Self.importResult(url, into: shared.library) }
    }

    /// A sparse file that claims 2 GB: refused from its size, without reading it.
    @Test func aTwoGigabyteFileIsRefusedUnread() throws {
        let (library, _) = try TacticLibraryTests.make()
        let url = try folder().appendingPathComponent("huge.tactic")
        try Fixtures.data("overlap-left").write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: 2 << 30)
        try handle.close()

        let start = ContinuousClock.now
        let outcome = try #require(importOutcome(url, into: library), "importFile hung")
        #expect(outcome == .failure(.unreadable))
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    /// A named pipe with nobody writing: opening it to read would wait forever.
    @Test func aNamedPipeIsRefusedNotWaitedOn() throws {
        let (library, _) = try TacticLibraryTests.make()
        let url = try folder().appendingPathComponent("pipe.tactic")
        #expect(mkfifo(url.path, 0o644) == 0)
        defer {
            // If a read is stuck on the pipe, opening its write end lets it finish.
            let writer = open(url.path, O_WRONLY | O_NONBLOCK)
            if writer >= 0 { close(writer) }
        }
        let outcome = importOutcome(url, into: library)
        #expect(outcome == .failure(.unreadable), "outcome: \(String(describing: outcome))")
    }

    /// Only a regular file is read: a pipe that already holds a whole tactic is refused too.
    @Test func aPipeHoldingATacticIsRefused() throws {
        let (library, _) = try TacticLibraryTests.make()
        let url = try folder().appendingPathComponent("full-pipe.tactic")
        #expect(mkfifo(url.path, 0o644) == 0)
        // Our reader keeps the written bytes in the pipe; with the writer closed, a read gets them and then the end.
        let reader = open(url.path, O_RDONLY | O_NONBLOCK)
        defer { close(reader) }
        let writer = open(url.path, O_WRONLY | O_NONBLOCK)
        let tactic = try TestTactics.data(TestTactics.small())
        #expect(tactic.withUnsafeBytes { write(writer, $0.baseAddress, $0.count) } == tactic.count)
        close(writer)
        #expect(importOutcome(url, into: library) == .failure(.unreadable))
    }

    @Test func aFolderNamedLikeATacticIsRefused() throws {
        let (library, _) = try TacticLibraryTests.make()
        let url = try folder().appendingPathComponent("folder.tactic", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        #expect(importOutcome(url, into: library) == .failure(.unreadable))
    }

    /// An endless device is not a regular file, so it's refused before any read.
    @Test func anEndlessDeviceIsRefusedAfterTheCap() throws {
        let (library, _) = try TacticLibraryTests.make()
        #expect(importOutcome(URL(fileURLWithPath: "/dev/zero"), into: library) == .failure(.unreadable))
    }

    @Test func aSymlinkLoopIsRefused() throws {
        let (library, _) = try TacticLibraryTests.make()
        let dir = try folder()
        let a = dir.appendingPathComponent("a.tactic")
        let b = dir.appendingPathComponent("b.tactic")
        try FileManager.default.createSymbolicLink(at: a, withDestinationURL: b)
        try FileManager.default.createSymbolicLink(at: b, withDestinationURL: a)
        #expect(importOutcome(a, into: library) == .failure(.unreadable))
    }
}
