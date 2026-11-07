import Foundation

/// Bringing tactics in (D-56): a `.tactic` from AirDrop, WhatsApp or Files, and the example move on first launch.
extension TacticLibrary {
    /// Checks an outside file with `TacticFormat` and copies it in; returns the copy's URL. A tactic whose id is
    /// already in the library gets a new id, so the two stay apart. A file already in the library is opened as is.
    func importFile(from external: URL) throws(TacticFormatError) -> URL {
        let accessing = external.startAccessingSecurityScopedResource()
        defer { if accessing { external.stopAccessingSecurityScopedResource() } }

        let parent = external.deletingLastPathComponent().resolvingSymlinksInPath().path
        if parent == folder.resolvingSymlinksInPath().path {
            _ = try load(external)
            return external
        }

        var tactic = try load(external)
        let existingIDs = Set(((try? entries())?.entries ?? []).map(\.tactic.id))
        if existingIDs.contains(tactic.id) { tactic.id = UUID().uuidString }
        guard let url = try? write(tactic, to: uniqueURL(for: tactic.title)) else { throw .unreadable }

        // The system may hand a shared file over as a copy in Documents/Inbox; that copy is no longer needed.
        if parent == folder.appendingPathComponent("Inbox", isDirectory: true).resolvingSymlinksInPath().path {
            try? FileManager.default.removeItem(at: external)
        }
        return url
    }

    /// Adds the example move on the very first launch only; deleting it later doesn't bring it back. If the bundled
    /// example can't be read, the next launch tries again.
    func seedExampleIfFirstLaunch() {
        guard !defaults.bool(forKey: Self.seededKey), let exampleURL, var tactic = try? load(exampleURL) else { return }
        tactic.title = Self.exampleTitle
        guard (try? write(tactic, to: uniqueURL(for: tactic.title))) != nil else { return }
        defaults.set(true, forKey: Self.seededKey)
    }
}
