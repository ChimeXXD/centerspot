import Observation
import SwiftUI

/// A tactic opened on the board: where its file is and what it held when it was opened.
struct OpenTactic: Hashable {
    let url: URL
    let tactic: Tactic
    /// Made by New tactic just now; closed untouched, it's discarded.
    var isNew = false
    /// Opened from the library's Export video (D-89): the board opens on the export sheet.
    var opensExport = false
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
    /// The file name of the move opened last, which the library plays at the top (D-89).
    nonisolated static let lastOpenedKey = "library.lastOpened"

    /// The example move's id (D-29), to tell when it is the only move.
    let exampleID: String?
    /// The file name of the move opened last (D-89). Stored here so the library redraws when it changes; kept in
    /// `lastOpenedKey` across launches.
    private(set) var lastOpened: String? {
        didSet { library.defaults.set(lastOpened, forKey: Self.lastOpenedKey) }
    }

    /// Saves the open board now; set by the board while it's on screen.
    private var flusher: (board: UUID, flush: () -> Void)?

    init(library: TacticLibrary) {
        self.library = library
        exampleID = library.exampleURL.flatMap { try? library.load($0) }?.id
        lastOpened = library.defaults.string(forKey: Self.lastOpenedKey)
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

    /// The example move (D-29): opened from its card, or added again first if it was deleted. Start on the last
    /// welcome page lands here (D-58).
    func openExample() {
        guard let url = library.exampleURL, let example = try? library.load(url) else { return }
        if let entry = entries.first(where: { $0.tactic.id == example.id }) {
            open(entry.url)
        } else {
            importAndOpen(url)
        }
    }

    func open(_ url: URL, isNew: Bool = false, opensExport: Bool = false) {
        do {
            path.append(OpenTactic(url: url, tactic: try library.load(url), isNew: isNew, opensExport: opensExport))
            lastOpened = url.lastPathComponent
        } catch {
            alert = error.message
            refresh()
        }
    }

    /// The move the library plays at the top (D-89): the one opened last, or the newest.
    var resumeEntry: TacticLibrary.Entry? { lastOpenedEntry ?? entries.first }

    /// The move opened last, if it's still in the library.
    var lastOpenedEntry: TacticLibrary.Entry? {
        entries.first { $0.url.lastPathComponent == lastOpened }
    }

    /// Only the example is in the library: the top says "Example" and the grid says what to do.
    var onlyExample: Bool {
        entries.count == 1 && entries[0].tactic.id == exampleID
    }

    func rename(_ entry: TacticLibrary.Entry, to title: String) {
        // An unchanged title would rewrite the file and move it to the top of the library.
        guard TacticLibrary.cleanTitle(title) != entry.tactic.title else { return }
        perform { try follow(entry.url, to: library.rename(entry.url, to: title)) }
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
            follow(url, to: saved)
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
        // centerspot:// links arrive with sharing (D-10); only files are handled here.
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

    /// A new title renames the file: if it was the move opened last, the library keeps playing it at the top.
    private func follow(_ old: URL, to new: URL) {
        if new != old, lastOpened == old.lastPathComponent { lastOpened = new.lastPathComponent }
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
