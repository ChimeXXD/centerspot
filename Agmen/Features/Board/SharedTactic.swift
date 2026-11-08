import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The board's Share (D-83): the tactic on screen as a `.tactic` file named after its title, for AirDrop, Files or a
/// chat. Written to a fresh temporary folder when the share sheet asks for it, so two shares never collide.
struct SharedTactic: Transferable {
    let tactic: Tactic

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .tactic) { shared in
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            return SentTransferredFile(try shared.write(into: folder))
        }
    }

    /// Writes the file into `folder` (made if needed) and returns its URL.
    func write(into folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(TacticLibrary.fileStem(for: tactic.title)).appendingPathExtension("tactic")
        try TacticFormat.encode(tactic).write(to: url, options: .atomic)
        return url
    }
}
