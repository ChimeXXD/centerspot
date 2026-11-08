import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// BR-2 (D-66, D-76): a video exported through the broadcast camera. The board is `BoardRenderer`'s own broadcast
/// drawing of the same instant, looking where `CameraTrack` says (D-07, D-06); it fills the frame's width as in the
/// mockup's export frames; and the video carries the camera from its settings.
extension ExportFrameTests {
    static let videoCanvases: [ExportCanvas] = [.vertical, .square, .wide]

    @Test(arguments: videoCanvases)
    func theBroadcastBoardIsTheRenderersOwnDrawing(canvas: ExportCanvas) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = ExportFrame(tactic: hero, canvas: canvas, showsTitle: false, showsNotes: false, camera: .broadcast)
        let t = 2.4
        let image = try #require(frame.image(at: t))
        // The corner mark may sit over a broadcast board (the mockup's 16:9), so compare above it.
        let board = frame.layout.board
        let top = min(board.maxY, frame.layout.mark.rect.minY) - board.minY
        let area = CGRect(x: board.minX, y: board.minY, width: board.width, height: top)
        let own = try #require(BoardRenderer.image(state: Timeline.state(at: t, in: hero), tactic: hero, size: board.size,
                                                   options: .init(broadcast: CameraTrack(tactic: hero).target(at: t))))
        let crop = try #require(image.cropping(to: area))
        let ownCrop = try #require(own.cropping(to: CGRect(x: 0, y: 0, width: board.width, height: top)))
        let share = VideoReader.share(try VideoReader.bgra(crop), try VideoReader.bgra(ownCrop), within: 2)
        #expect(share == 1, "\(canvas): \(share)")
        // And it is not the flat board.
        let flat = try #require(BoardRenderer.image(state: Timeline.state(at: t, in: hero), tactic: hero, size: board.size))
        let flatCrop = try #require(flat.cropping(to: CGRect(x: 0, y: 0, width: board.width, height: top)))
        #expect(VideoReader.share(try VideoReader.bgra(crop), try VideoReader.bgra(flatCrop), within: 2) < 0.9)
    }

    /// The mockup's broadcast frames: 9:16 and 1:1 run the board edge to edge under the text band; 16:9 is all board.
    @Test func theBroadcastBoardFillsTheFrame() {
        for canvas in Self.videoCanvases {
            let layout = ExportLayout.make(canvas, kind: .full, showsTitle: true, showsNote: true, broadcast: true)
            #expect(layout.board.minX == 0 && layout.board.width == layout.canvas.width, "\(canvas): \(layout.board)")
            if case .wide = canvas { #expect(layout.board == CGRect(origin: .zero, size: layout.canvas)) }
            let flat = ExportLayout.make(canvas, kind: .full, showsTitle: true, showsNote: true)
            #expect(layout.title == flat.title && layout.note == flat.note && layout.mark == flat.mark, "\(canvas)")
        }
    }

    /// Text over a broadcast board (the 16:9 title and note, the mark) is drawn after it, so the board never hides it.
    @Test func textOverTheBroadcastBoardStaysOnTop() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let with = ExportFrame(tactic: hero, canvas: .wide, showsTitle: true, showsNotes: true, camera: .broadcast)
        let without = ExportFrame(tactic: hero, canvas: .wide, showsTitle: false, showsNotes: false, camera: .broadcast)
        let t = with.duration
        let title = try #require(with.layout.title).rect
        let withImage = try #require(with.image(at: t)), withoutImage = try #require(without.image(at: t))
        let a = try VideoReader.bgra(try #require(withImage.cropping(to: title)))
        let b = try VideoReader.bgra(try #require(withoutImage.cropping(to: title)))
        #expect(VideoReader.share(a, b, within: 2) < 0.97, "the title shows over the board")
    }

    @Test func broadcastFramesAreTheSameEveryTime() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true, camera: .broadcast)
        let again = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true, camera: .broadcast)
        for t in [0, 1.1, 3.3, 6.5] {
            #expect(try VideoReader.bgra(try #require(frame.image(at: t))) == VideoReader.bgra(try #require(again.image(at: t))),
                    "t = \(t)")
        }
    }

    /// The exported video is drawn through the camera its settings name: its last frame is the broadcast end frame.
    @Test func theVideoUsesTheCameraInItsSettings() async throws {
        let hero = try Fixtures.tactic("overlap-left")
        let result = try await VideoExporter.export(hero, settings: VideoExportSettings(camera: .broadcast))
        defer { VideoExporter.discard(result.url) }
        let decoded = try await VideoReader.frames(result.url, at: [result.frames - 1])
        let last = try #require(decoded[result.frames - 1])
        let broadcast = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true, camera: .broadcast)
        let flat = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true)
        let share = VideoReader.share(last, try VideoReader.bgra(try #require(broadcast.image(at: broadcast.duration))), within: 32)
        #expect(share >= 0.98, "\(share)")
        let blind = VideoReader.share(last, try VideoReader.bgra(try #require(flat.image(at: flat.duration))), within: 32)
        #expect(blind < 0.98, "\(blind)")
    }
}
