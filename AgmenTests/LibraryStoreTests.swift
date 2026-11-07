import Foundation
import Testing
@testable import Agmen

/// Closing the board: a New tactic left untouched leaves no empty "Untitled tactic" behind (D-56).
@MainActor
struct LibraryStoreTests {
    @Test func anUntouchedNewTacticIsDiscardedWhenTheBoardCloses() throws {
        let (library, _) = try TacticLibraryTests.make()
        let store = LibraryStore(library: library)
        store.newTactic()
        let open = try #require(store.path.last)
        #expect(open.isNew)
        store.close(open, at: open.url, leaving: open.tactic)
        #expect(!FileManager.default.fileExists(atPath: open.url.path))
        #expect(!store.entries.contains { $0.url == open.url })
        #expect(store.entries.count == 1, "only the seeded example is left")
    }

    @Test func anEditedNewTacticIsKept() throws {
        let (library, _) = try TacticLibraryTests.make()
        let store = LibraryStore(library: library)
        store.newTactic()
        let open = try #require(store.path.last)
        var edited = open.tactic
        _ = TacticEdits.addToken(.ourPlayer, in: &edited)
        let url = try #require(store.save(edited, to: open.url))
        store.close(open, at: url, leaving: edited)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func anExistingTacticOpenedAndClosedUntouchedIsKept() throws {
        let (library, _) = try TacticLibraryTests.make()
        let store = LibraryStore(library: library)
        let entry = try #require(store.entries.first)
        store.open(entry.url)
        let open = try #require(store.path.last)
        #expect(!open.isNew)
        store.close(open, at: open.url, leaving: open.tactic)
        #expect(FileManager.default.fileExists(atPath: entry.url.path))
    }

    /// 14a: a file opened again from Files while its board is open must show the board's latest edits, not the
    /// version on disk from before the last autosave.
    @Test func reopeningAnOpenTacticSavesTheBoardFirst() throws {
        let (library, _) = try TacticLibraryTests.make()
        let store = LibraryStore(library: library)
        let entry = try #require(store.entries.first)
        store.open(entry.url)
        var edited = try #require(store.path.last).tactic
        TacticEdits.setDuration(3, step: 0, in: &edited)
        let board = UUID()
        store.registerFlush(board) { _ = store.save(edited, to: entry.url) }
        store.importAndOpen(entry.url)
        #expect(store.path.count == 1)
        #expect(store.path.last?.tactic == edited)
    }

    @Test func aClosedBoardNoLongerFlushes() throws {
        let (library, _) = try TacticLibraryTests.make()
        let store = LibraryStore(library: library)
        var flushed = 0
        let a = UUID(), b = UUID()
        store.registerFlush(a) { flushed += 1 }
        store.registerFlush(b) { flushed += 10 }
        store.unregisterFlush(a)  // the old board closing after the new one opened keeps the new one's flush
        store.flushOpenBoard()
        #expect(flushed == 10)
        store.unregisterFlush(b)
        store.flushOpenBoard()
        #expect(flushed == 10)
    }
}
