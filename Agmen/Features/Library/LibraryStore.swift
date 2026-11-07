import Observation
import SwiftUI

/// A tactic opened on the board: where its file is and what it held when it was opened.
struct OpenTactic: Hashable {
    let url: URL
    let tactic: Tactic
    /// Made by New tactic just now; closed untouched, it's discarded.
    var isNew = false
}

/// The library's state (D-56): the tactics on disk, the navigation path, and a plain message to show when
/// something fails. Every change goes through `TacticLibrary` and then re-reads the folder.
@MainActor @Observable
final class LibraryStore {
    let library: TacticLibrary
    private(set) var entries: [TacticLibrary.Entry] = []
    /// Files in the folder that couldn't be read (shown as a count, never a crash).
    private(set) var skipped = 0
    var path: [OpenTactic] = []
    /// A plain message for an alert ("This file isn't a tactic we can open.").
    var alert: String?

    static let failedMessage = "That didn't work. Try again."

    /// Saves the open board now; set by the board while it's on screen.
    private var flusher: (board: UUID, flush: () -> Void)?

    init(library: TacticLibrary) {
        self.library = library
        library.seedExampleIfFirstLaunch()
        refresh()
    }

    func refresh() {
        let listing = (try? library.entries()) ?? TacticLibrary.Listing()
        entries = listing.entries
        skipped = listing.skipped
    }

    /// A blank tactic, opened on the board (which starts on the formation picker).
    func newTactic() {
        if let url = perform({ try library.create() }) { open(url, isNew: true) }
    }

    func open(_ url: URL, isNew: Bool = false) {
        do {
            path.append(OpenTactic(url: url, tactic: try library.load(url), isNew: isNew))
        } catch {
            alert = error.message
            refresh()
        }
    }

    func rename(_ entry: TacticLibrary.Entry, to title: String) {
        // An unchanged title would rewrite the file and move it to the top of the library.
        guard TacticLibrary.cleanTitle(title) != entry.tactic.title else { return }
        perform { try library.rename(entry.url, to: title) }
    }

    func duplicate(_ entry: TacticLibrary.Entry) {
        perform { try library.duplicate(entry.url) }
    }

    func delete(_ entry: TacticLibrary.Entry) {
        perform { try library.delete(entry.url) }
    }

    /// Saves the board's tactic. Returns where the file now lives (renamed when the title changed), or `nil` if the
    /// write failed, so the board tries again on its next save. While the board is open the library is hidden, so the
    /// folder is re-read only once the board has closed (the library also re-reads it when it appears).
    func save(_ tactic: Tactic, to url: URL) -> URL? {
        do {
            let saved = try library.save(tactic, to: url)
            if path.isEmpty { refresh() }
            return saved
        } catch {
            alert = Self.failedMessage
            return nil
        }
    }

    /// The board closed. A New tactic nobody touched leaves no empty "Untitled tactic" card behind.
    func close(_ open: OpenTactic, at url: URL, leaving tactic: Tactic) {
        guard open.isNew, tactic == open.tactic else { return }
        try? library.delete(url)
        refresh()
    }

    func registerFlush(_ board: UUID, _ flush: @escaping () -> Void) {
        flusher = (board, flush)
    }

    /// A board that closes after the next one opened leaves the new board's flush in place.
    func unregisterFlush(_ board: UUID) {
        if flusher?.board == board { flusher = nil }
    }

    func flushOpenBoard() {
        flusher?.flush()
    }

    /// A `.tactic` handed to the app (AirDrop, WhatsApp, Files): checked, copied in, then opened from the library.
    func importAndOpen(_ url: URL) {
        // agmen:// links arrive with sharing (D-10); only files are handled here.
        guard url.isFileURL else { return }
        // The open board may hold edits not yet on disk, and this may be its own file: save them before reading.
        flushOpenBoard()
        do {
            let copy = try library.importFile(from: url)
            refresh()
            path = []
            open(copy)
        } catch {
            alert = error.message
        }
    }

    @discardableResult
    private func perform<T>(_ work: () throws -> T) -> T? {
        defer { refresh() }
        do {
            return try work()
        } catch {
            alert = Self.failedMessage
            return nil
        }
    }
}
