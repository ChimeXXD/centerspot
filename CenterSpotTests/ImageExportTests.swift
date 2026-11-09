import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CenterSpot

/// D5-2, SPEC §7: the step PNG is twice the board's on-screen width in pixels and shows that step as the board does;
/// the lineup card (D-63) lists every one of our players in shirt-number order without overlaps.
struct ImageExportTests {
    @Test(arguments: [(402.0, 804), (354.0, 708), (1024.0, 2048)])
    func thePNGIsTwiceTheBoardsWidth(points: Double, pixels: Int) async throws {
        let hero = try Fixtures.tactic("overlap-left")
        let result = try await ImageExporter.exportStep(hero, step: 2, boardWidth: points, showsTitle: true, showsNotes: true)
        defer { VideoExporter.discard(result.url) }
        let data = try Data(contentsOf: result.url)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == pixels, "\(points) pt → \(image.width) px")
        #expect(result.width == pixels && result.height == image.height)
        let layout = ExportLayout.make(.image(width: pixels), kind: hero.pitch.kind, showsTitle: true, showsNote: true)
        #expect(image.height == Int(layout.canvas.height))
        #expect(result.bytes == data.count)
        #expect(result.url.pathExtension == "png" && result.url.deletingPathExtension().lastPathComponent == hero.title)
    }

    /// The board in the PNG is the chosen step at rest, drawn by `BoardRenderer` (D-07), with the mark (D-38).
    @Test func thePNGShowsTheChosenStep() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let image = try #require(ImageExporter.stepImage(hero, step: 2, boardWidth: 354))
        let layout = ExportLayout.make(.image(width: 708), kind: hero.pitch.kind, showsTitle: true, showsNote: true)
        let crop = try VideoReader.bgra(try #require(image.cropping(to: layout.board)))
        func board(_ step: Int) throws -> Data {
            try VideoReader.bgra(try #require(BoardRenderer.image(state: Timeline.restingState(step: step, in: hero),
                                                                  tactic: hero, size: layout.board.size)))
        }
        #expect(VideoReader.share(crop, try board(2), within: 1) == 1)
        #expect(VideoReader.share(crop, try board(0), within: 1) < 0.99, "not another step")
        #expect(try ExportFrameTests.inkShare(image, in: layout.mark.rect) > 0.02)
        #expect(try ExportFrameTests.inkShare(image, in: try #require(layout.note).rect) > 0.01, "step 3's note")
    }

    @Test func theLineupListsEveryPlayerInNumberOrder() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let card = LineupCard(hero)
        let home = hero.tokens.filter { $0.kind == .player && $0.side == .home }
        #expect(card.rows.count == home.count && card.rows.count == 11)
        #expect(Set(card.rows.map(\.tokenID)) == Set(home.map(\.id)))
        let numbers = card.rows.compactMap(\.number)
        #expect(numbers == numbers.sorted() && numbers.count == 11)
        #expect(card.tactic.tokens.allSatisfy { $0.side == .home }, "the team sheet is our side")
        #expect(card.shape == "4-3-3")
        let image = try #require(card.image())
        #expect(image.width == 1080 && image.height == 1350)
        #expect(try ExportFrameTests.inkShare(image, in: LineupCard.markBox.rect) > 0.02)
    }

    /// Eleven names of 24 characters (the longest a file allows) of the widest letter still fit their rows on at most
    /// two lines, readable, and no row overlaps another or the pitch.
    @Test func longNamesDoNotOverlap() throws {
        var hero = try Fixtures.tactic("overlap-left")
        for i in hero.tokens.indices where hero.tokens[i].side == .home {
            hero.tokens[i].name = String(repeating: "W", count: Token.maxNameLength)
        }
        let card = LineupCard(hero)
        #expect(card.nameSize >= LineupCard.nameSizes.lowerBound, "\(card.nameSize)")
        let pitch = BoardGeometry(kind: hero.pitch.kind, fitting: LineupCard.boardRect).pitchRect
        for (i, row) in card.rows.enumerated() {
            let height = ExportText.height(row.name, face: .title, size: card.nameSize, width: row.nameRect.width)
            #expect(height <= row.nameRect.height, "\(row.name) at \(card.nameSize): \(height)")
            #expect(height <= card.nameSize * 3, "two lines at most")
            #expect(LineupCard.listRect.contains(row.rect) && row.rect.minX > pitch.maxX)
            #expect(row.disc.x + row.discRadius < row.nameRect.minX, "the disc stays left of the name")
            for other in card.rows.dropFirst(i + 1) { #expect(!row.rect.intersects(other.rect)) }
        }
        let real = LineupCard(try Fixtures.tactic("overlap-left"))
        #expect(real.nameSize >= 28, "short names stay big: \(real.nameSize)")
    }
}
