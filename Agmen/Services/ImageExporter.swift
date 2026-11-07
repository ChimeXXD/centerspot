import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// PNG exports (SPEC §7): the step on screen, and the lineup card (D-63). Both draw the board with `BoardRenderer`
/// (D-07) and carry the corner mark (D-38).
enum ImageExporter {
    struct Result: Sendable, Equatable {
        let url: URL
        let bytes: Int
        let width: Int
        let height: Int
    }

    enum ExportError: Error, Equatable {
        case drawing
    }

    /// D5-2: twice the board's on-screen width in points (a 402 pt board gives 804 px).
    static func pixelWidth(boardWidth: CGFloat) -> Int { Int((boardWidth * 2).rounded()) }

    /// The step at rest as the editor shows it, in the export look: title band, the step's note, the board, the mark.
    static func stepImage(_ tactic: Tactic, step: Int, boardWidth: CGFloat, showsTitle: Bool = true,
                          showsNotes: Bool = true) -> CGImage? {
        let frame = ExportFrame(tactic: tactic, canvas: .image(width: pixelWidth(boardWidth: boardWidth)),
                                showsTitle: showsTitle, showsNotes: showsNotes)
        return frame.image(state: Timeline.restingState(step: step, in: tactic))
    }

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The step image written to a temporary `<title>.png`, off the main actor.
    @concurrent
    static func exportStep(_ tactic: Tactic, step: Int, boardWidth: CGFloat, showsTitle: Bool,
                           showsNotes: Bool) async throws -> Result {
        let image = stepImage(tactic, step: step, boardWidth: boardWidth, showsTitle: showsTitle, showsNotes: showsNotes)
        return try write(image, title: tactic.title)
    }

    /// The lineup card written to a temporary `<title> lineup.png`, off the main actor.
    @concurrent
    static func exportLineup(_ tactic: Tactic) async throws -> Result {
        try write(LineupCard(tactic).image(), title: "\(tactic.title) lineup")
    }

    private static func write(_ image: CGImage?, title: String) throws -> Result {
        guard let image, let data = png(image) else { throw ExportError.drawing }
        let url = VideoExporter.temporaryURL(title: title, fileExtension: "png")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        } catch {
            VideoExporter.discard(url)
            throw error
        }
        return Result(url: url, bytes: data.count, width: image.width, height: image.height)
    }
}
