import Foundation
import Testing
@testable import Agmen

/// The board's Share (D-83): the tactic on screen goes out as a `.tactic` file named after its title, readable by the
/// importer.
struct SharedTacticTests {
    @Test func writesAReadableFileNamedAfterTheTitle() throws {
        var tactic = try Fixtures.tactic("overlap-left")
        tactic.title = "Press: high/left"
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = try SharedTactic(tactic: tactic).write(into: folder)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(url.lastPathComponent == "Press- high-left.tactic")
        #expect(try TacticFormat.decode(Data(contentsOf: url)) == tactic)
    }
}
