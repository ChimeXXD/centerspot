import Foundation
import Testing
@testable import CenterSpot

/// D-56: CenterSpot's own library of `.tactic` files. Every test works in its own temporary folder and defaults suite,
/// never the app's real Documents.
struct TacticLibraryTests {
    // MARK: File names

    @Test(arguments: [
        ("Overlap down the left", "Overlap down the left"),
        ("  4/4 press: high  ", "4-4 press- high"),
        ("", "Untitled tactic"),
        ("   \n ", "Untitled tactic"),
        ("..hidden", "hidden"),
        (" ..hidden ", "hidden"),
        ("/", "-"),
        // Control characters can't all live in a file name (NUL never can), so they become spaces (D6-3 fuzz).
        ("Sm\u{0}all", "Sm all"),
        ("Low\nblock\t", "Low block"),
        ("\u{1}\u{7F}", "Untitled tactic"),
        // Format characters stay: the joiner holds an emoji family together.
        ("\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} press", "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} press"),
    ])
    func fileStemIsSafe(_ title: String, _ stem: String) {
        #expect(TacticLibrary.fileStem(for: title) == stem)
    }

    @Test func aVeryLongTitleGetsAShortFileName() {
        let stem = TacticLibrary.fileStem(for: String(repeating: "a", count: 500))
        #expect(stem.count == TacticLibrary.maxStemLength)
    }

    @Test func aLongEmojiTitleStaysUnderTheByteLimit() throws {
        let title = String(repeating: "🏃🏾‍♂️", count: 120)  // 17 bytes each
        let stem = TacticLibrary.fileStem(for: title)
        #expect(stem.utf8.count <= TacticLibrary.maxStemBytes)
        #expect(!stem.isEmpty)
        let (library, _) = try make()
        var tactic = TestTactics.small()
        tactic.title = title
        let url = try library.write(tactic, to: library.uniqueURL(for: title))
        #expect(try library.load(url).title == title)
    }

    @Test(arguments: [("  Back three  ", "Back three"), ("", "Untitled tactic"), (" \t", "Untitled tactic")])
    func cleanTitleTrimsAndFallsBack(_ raw: String, _ clean: String) {
        #expect(TacticLibrary.cleanTitle(raw) == clean)
    }

    // MARK: Create and list

    @Test func createWritesABlankTactic() throws {
        let (library, _) = try make()
        let url = try library.create()
        #expect(url.lastPathComponent == "Untitled tactic.tactic")
        #expect(url.deletingLastPathComponent().standardizedFileURL == library.folder.standardizedFileURL)
        let tactic = try library.load(url)
        #expect(tactic.title == "Untitled tactic")
        #expect(tactic.tokens.isEmpty)
    }

    @Test func namesAreDeduplicated() throws {
        let (library, _) = try make()
        let names = try (0..<3).map { _ in try library.create().lastPathComponent }
        #expect(names == ["Untitled tactic.tactic", "Untitled tactic 2.tactic", "Untitled tactic 3.tactic"])
        // Three blank tactics, three different ids.
        #expect(Set(try library.entries().entries.map(\.tactic.id)).count == 3)
    }

    @Test func entriesAreNewestFirst() throws {
        let (library, _) = try make()
        let old = try library.write(TestTactics.small(), title: "Old")
        let new = try library.write(try Fixtures.tactic("overlap-left"), title: "New")
        let middle = try library.write(try Fixtures.tactic("full-11v11"), title: "Middle")
        try touch(old, Date(timeIntervalSinceNow: -300))
        try touch(middle, Date(timeIntervalSinceNow: -200))
        try touch(new, Date(timeIntervalSinceNow: -100))
        #expect(try library.entries().entries.map(\.tactic.title) == ["New", "Middle", "Old"])
    }

    @Test func unreadableFilesAreSkippedAndCounted() throws {
        let (library, folder) = try make()
        _ = try library.write(TestTactics.small(), title: "Good")
        try Data("not json".utf8).write(to: folder.appendingPathComponent("Broken.tactic"))
        // Valid JSON padded past 256 KB: refused for its size alone.
        var big = try TacticFormat.encode(TestTactics.small())
        big.append(Data(repeating: 0x20, count: TacticFormat.maxByteCount))
        try big.write(to: folder.appendingPathComponent("Big.tactic"))
        // Other files are not tactics and are not counted.
        try Data("hello".utf8).write(to: folder.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Inbox"), withIntermediateDirectories: true)

        let listing = try library.entries()
        #expect(listing.entries.map(\.tactic.title) == ["Good"])
        #expect(listing.skipped == 2)
    }

    @Test func anEmptyOrMissingFolderListsNothing() throws {
        let (library, folder) = try make()
        #expect(try library.entries().entries.isEmpty)
        let missing = TacticLibrary(folder: folder.appendingPathComponent("nope"), defaults: library.defaults)
        #expect(try missing.entries().entries.isEmpty)
    }

    // MARK: Save, rename, duplicate, delete

    @Test func saveWritesTheTactic() throws {
        let (library, _) = try make()
        let url = try library.write(try Fixtures.tactic("overlap-left"), title: "Overlap")
        var tactic = try library.load(url)
        tactic.pitch.style = .plain
        TacticEdits.setDuration(2.5, step: 1, in: &tactic)
        let saved = try library.save(tactic, to: url)
        #expect(saved == url)
        #expect(try library.load(url) == tactic)
    }

    @Test func saveRenamesTheFileWhenTheTitleChanged() throws {
        let (library, folder) = try make()
        let url = try library.create()
        var tactic = try library.load(url)
        tactic.title = "Back three"
        let saved = try library.save(tactic, to: url)
        #expect(saved.lastPathComponent == "Back three.tactic")
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(try names(in: folder) == ["Back three.tactic"])
        #expect(try library.load(saved).title == "Back three")
    }

    @Test func saveKeepsADeduplicatedName() throws {
        let (library, folder) = try make()
        _ = try library.create()
        let second = try library.create()  // "Untitled tactic 2"
        var tactic = try library.load(second)
        tactic.pitch.style = .plain
        #expect(try library.save(tactic, to: second) == second)
        #expect(try names(in: folder) == ["Untitled tactic 2.tactic", "Untitled tactic.tactic"])
    }

    @Test func saveKeepsItsNumberWhenALowerOneIsFree() throws {
        let (library, folder) = try make()
        _ = try library.create()
        let second = try library.create()
        let third = try library.create()
        try library.delete(second)
        var tactic = try library.load(third)
        tactic.pitch.style = .plain
        #expect(try library.save(tactic, to: third) == third, "saving doesn't shuffle names")
        #expect(try names(in: folder) == ["Untitled tactic 3.tactic", "Untitled tactic.tactic"])
    }

    @Test func renameChangesTheTitleAndTheFileName() throws {
        let (library, folder) = try make()
        let url = try library.create()
        let renamed = try library.rename(url, to: "  4/4 press  ")
        #expect(renamed.lastPathComponent == "4-4 press.tactic")
        #expect(try library.load(renamed).title == "4/4 press")
        #expect(try names(in: folder) == ["4-4 press.tactic"])
    }

    @Test func renameToAnotherTacticsNameDeduplicates() throws {
        let (library, _) = try make()
        _ = try library.write(TestTactics.small(), title: "Press")
        let url = try library.create()
        #expect(try library.rename(url, to: "Press").lastPathComponent == "Press 2.tactic")
    }

    @Test func renameOnlyChangingCaseKeepsOneFile() throws {
        let (library, folder) = try make()
        let url = try library.write(TestTactics.small(), title: "press")
        let renamed = try library.rename(url, to: "Press")
        #expect(renamed.lastPathComponent == "Press.tactic")
        #expect(try names(in: folder) == ["Press.tactic"])
        #expect(try library.load(renamed).title == "Press")
    }

    @Test func theFileBeingRenamedCountsAsFree() throws {
        let (library, _) = try make()
        let url = try library.write(TestTactics.small(), title: "Press")
        #expect(library.uniqueURL(for: "Press", replacing: url) == url)
        #expect(library.uniqueURL(for: "Press").lastPathComponent == "Press 2.tactic")
    }

    @Test func renameToEmptyFallsBack() throws {
        let (library, _) = try make()
        let url = try library.write(TestTactics.small(), title: "Press")
        let renamed = try library.rename(url, to: "   ")
        #expect(renamed.lastPathComponent == "Untitled tactic.tactic")
        #expect(try library.load(renamed).title == "Untitled tactic")
    }

    @Test func duplicateMakesACopyWithANewID() throws {
        let (library, _) = try make()
        let original = try library.write(try Fixtures.tactic("overlap-left"), title: "Overlap down the left")
        let copy = try library.duplicate(original)
        #expect(copy.lastPathComponent == "Overlap down the left copy.tactic")
        let a = try library.load(original), b = try library.load(copy)
        #expect(b.title == "Overlap down the left copy")
        #expect(b.id != a.id)
        #expect(b.tokens == a.tokens && b.phases == a.phases)
    }

    @Test func deleteRemovesTheFile() throws {
        let (library, folder) = try make()
        let url = try library.create()
        try library.delete(url)
        #expect(try names(in: folder).isEmpty)
    }

    /// 14b: names that differ only in case never coexist. The simulator refuses "press.tactic" next to
    /// "Press.tactic" yet says it doesn't exist; a case-sensitive disk would keep both and later fail a rename.
    @Test func aNameDifferingOnlyInCaseGetsANumber() throws {
        let (library, _) = try make()
        _ = try library.write(TestTactics.small(), title: "Press")
        #expect(library.uniqueURL(for: "press").lastPathComponent == "press 2.tactic")
    }

    @Test func renamingOntoAnotherTacticsNameInOtherCaseDeduplicates() throws {
        let (library, folder) = try make()
        let other = try library.write(TestTactics.small(), title: "Press")
        let mine = try library.create()
        let renamed = try library.rename(mine, to: "press")
        #expect(renamed.lastPathComponent == "press 2.tactic")
        #expect(try library.load(renamed).title == "press")
        #expect(try library.load(other).title == "Press")
        #expect(try names(in: folder).count == 2)
        // And back to "Press": still its own file, still numbered.
        #expect(try library.rename(renamed, to: "Press").lastPathComponent == "Press 2.tactic")
    }

    // MARK: Helpers

    /// A library over a fresh temporary folder and its own defaults suite.
    func make() throws -> (TacticLibrary, URL) {
        try TacticLibraryTests.make()
    }

    static func make() throws -> (TacticLibrary, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("library-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let suite = "centerspot.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let example = try #require(Bundle(for: LibraryBundleToken.self).url(forResource: "overlap-left", withExtension: "tactic"))
        return (TacticLibrary(folder: folder, defaults: defaults, exampleURL: example), folder)
    }

    func touch(_ url: URL, _ date: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".tactic") }.sorted()
    }
}

final class LibraryBundleToken {}

extension TacticLibrary {
    /// Test helper: writes `tactic` under `title` as a new file.
    func write(_ tactic: Tactic, title: String) throws -> URL {
        var tactic = tactic
        tactic.title = title
        let url = uniqueURL(for: title)
        try TacticFormat.encode(tactic).write(to: url, options: .atomic)
        return url
    }
}
