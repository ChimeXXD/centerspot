import Foundation

/// The user's tactics (D-56): `.tactic` files in the app's Documents folder, which Files shows under
/// On My iPhone › Agmen. Every read goes through `TacticFormat`, so a bad file is skipped, never a crash
/// (CLAUDE.md rule 4). Each file is named after its tactic's title.
struct TacticLibrary {
    struct Entry: Identifiable, Hashable {
        let url: URL
        let tactic: Tactic
        let modified: Date
        var id: URL { url }
    }

    /// The readable tactics, newest first, and how many files were skipped as unreadable.
    struct Listing {
        var entries: [Entry] = []
        var skipped = 0
    }

    static let fileExtension = "tactic"
    static let fallbackTitle = "Untitled tactic"
    /// File names stay well under the 255-byte limit even for long titles: at most this many characters…
    static let maxStemLength = 120
    /// …and this many UTF-8 bytes, so an emoji or accented title leaves room for " 99" and ".tactic".
    static let maxStemBytes = 200
    /// Set once the example move has been added, so deleting it never brings it back.
    static let seededKey = "library.seededExample"
    static let exampleTitle = "Overlap down the left"

    let folder: URL
    let defaults: UserDefaults
    /// The hero move (D-29) added on the first launch.
    var exampleURL: URL? = Bundle.main.url(forResource: "overlap-left", withExtension: "tactic")

    /// The app's Documents folder.
    static var documents: TacticLibrary {
        TacticLibrary(folder: URL.documentsDirectory, defaults: .standard)
    }

    // MARK: Names

    /// A title made safe as a file name: trimmed, `/` and `:` replaced, no leading dot, not empty, not too long.
    static func fileStem(for title: String) -> String {
        var stem = title.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        while stem.hasPrefix(".") { stem.removeFirst() }
        stem = String(stem.prefix(maxStemLength))
        while stem.utf8.count > maxStemBytes { stem.removeLast() }
        stem = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        return stem.isEmpty ? fallbackTitle : stem
    }

    /// The title as stored in the file: trimmed, never empty.
    static func cleanTitle(_ raw: String) -> String {
        let title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? fallbackTitle : title
    }

    /// A free file URL for `title`: "Press", then "Press 2", "Press 3"… Names are compared without case, so Agmen
    /// never makes two that differ only in case: a case-sensitive disk would keep them apart, a case-insensitive one
    /// refuses the second, and existence checks on either can't be trusted to agree. `current` (the file being
    /// renamed) doesn't count as taken, so changing only the case of a title doesn't add a number.
    func uniqueURL(for title: String, replacing current: URL? = nil) -> URL {
        let stem = Self.fileStem(for: title)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let taken = Set(names.filter { $0 != current?.lastPathComponent }.map { $0.lowercased() })
        var number = 1
        while true {
            let name = (number == 1 ? stem : "\(stem) \(number)") + "." + Self.fileExtension
            if !taken.contains(name.lowercased()) { return folder.appendingPathComponent(name) }
            number += 1
        }
    }

    /// Whether `url`'s name already belongs to `title`: its stem, or its stem with a dedupe number ("Press 2").
    static func name(of url: URL, matches title: String) -> Bool {
        let stem = fileStem(for: title)
        let name = url.deletingPathExtension().lastPathComponent
        if name == stem { return true }
        guard name.hasPrefix(stem + " "), let number = Int(name.dropFirst(stem.count + 1)) else { return false }
        return number >= 2
    }

    // MARK: Reading

    /// Every readable tactic in the folder, newest modification first. Unreadable or oversized files are skipped.
    func entries() throws -> Listing {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard FileManager.default.fileExists(atPath: folder.path) else { return Listing() }
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )
        var listing = Listing()
        for url in urls where url.pathExtension.lowercased() == Self.fileExtension {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            guard let tactic = try? load(url) else {
                listing.skipped += 1
                continue
            }
            listing.entries.append(Entry(url: url, tactic: tactic, modified: values?.contentModificationDate ?? .distantPast))
        }
        listing.entries.sort { ($0.modified, $1.url.lastPathComponent) > ($1.modified, $0.url.lastPathComponent) }
        return listing
    }

    /// Reads and checks one file. Over 256 KB is refused before it's read into memory.
    func load(_ url: URL) throws(TacticFormatError) -> Tactic {
        try TacticFormat.decode(Self.readCapped(url))
    }

    /// At most `maxByteCount + 1` bytes, so an oversized file is refused without loading all of it.
    static func readCapped(_ url: URL) throws(TacticFormatError) -> Data {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > TacticFormat.maxByteCount {
            throw .unreadable
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw .unreadable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: TacticFormat.maxByteCount + 1) else { throw .unreadable }
        guard data.count <= TacticFormat.maxByteCount else { throw .unreadable }
        return data
    }

    // MARK: Changes

    /// A new blank tactic (the board opens on the formation picker).
    func create() throws -> URL {
        let tactic = TacticDocument.blank()
        return try write(tactic, to: uniqueURL(for: tactic.title))
    }

    /// Writes `tactic` to `url` atomically. If its title no longer matches the file name, the file is renamed to
    /// match; returns where the tactic now lives.
    @discardableResult
    func save(_ tactic: Tactic, to url: URL) throws -> URL {
        try write(tactic, to: url)
        guard !Self.name(of: url, matches: tactic.title) else { return url }
        let destination = uniqueURL(for: tactic.title, replacing: url)
        try move(url, to: destination)
        return destination
    }

    /// Changes the title inside the file and the file's name.
    func rename(_ url: URL, to title: String) throws -> URL {
        var tactic = try load(url)
        tactic.title = Self.cleanTitle(title)
        return try save(tactic, to: url)
    }

    /// A copy titled "… copy" with its own id.
    func duplicate(_ url: URL) throws -> URL {
        var tactic = try load(url)
        tactic.id = UUID().uuidString
        tactic.title = Self.cleanTitle("\(tactic.title) copy")
        return try write(tactic, to: uniqueURL(for: tactic.title))
    }

    func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    @discardableResult
    func write(_ tactic: Tactic, to url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try TacticFormat.encode(tactic).write(to: url, options: .atomic)
        return url
    }

    /// Moves a file; a change of case only is a plain move too (checked by `renameOnlyChangingCaseKeepsOneFile`).
    private func move(_ url: URL, to destination: URL) throws {
        guard url.resolvingSymlinksInPath().path != destination.resolvingSymlinksInPath().path else { return }
        try FileManager.default.moveItem(at: url, to: destination)
    }
}
