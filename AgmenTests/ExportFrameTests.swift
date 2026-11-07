import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// SPEC §7, D-07, D-38, D-63: every export frame's layout keeps the corner mark, title and note off the pitch and
/// inside the canvas; the board in a frame is `BoardRenderer`'s own drawing; frames are a pure function of t.
struct ExportFrameTests {
    static let canvases: [ExportCanvas] = [.vertical, .square, .wide, .image(width: 708), .image(width: 804)]

    static func layouts() -> [(String, ExportLayout, Pitch.Kind)] {
        var all: [(String, ExportLayout, Pitch.Kind)] = []
        for canvas in canvases {
            for kind in Pitch.Kind.allCases {
                for (title, note) in [(true, true), (true, false), (false, true), (false, false)] {
                    let layout = ExportLayout.make(canvas, kind: kind, showsTitle: title, showsNote: note)
                    all.append(("\(canvas) \(kind) title \(title) note \(note)", layout, kind))
                }
            }
        }
        return all
    }

    @Test func nothingCoversThePitchAndEverythingFits() {
        for (name, layout, kind) in Self.layouts() {
            let canvas = CGRect(origin: .zero, size: layout.canvas)
            let pitch = layout.pitch(kind)
            let boxes = [layout.title, layout.note, layout.mark].compactMap { $0?.rect }
            #expect(canvas.contains(layout.board), "\(name): board")
            // A ringed player on the goal line reaches 1.61 disc radii past the pitch; text stays clear of that too.
            let reach = pitch.insetBy(dx: -1.62 * pitch.width * BoardGeometry.tokenRadiusRatio,
                                      dy: -1.62 * pitch.width * BoardGeometry.tokenRadiusRatio)
            for box in boxes {
                #expect(canvas.contains(box), "\(name): \(box) outside")
                #expect(!box.intersects(pitch), "\(name): \(box) over the pitch \(pitch)")
            }
            for box in [layout.title, layout.note].compactMap({ $0?.rect }) {
                #expect(!box.intersects(reach), "\(name): \(box) within a player's reach of the pitch \(pitch)")
            }
            for (i, a) in boxes.enumerated() {
                for b in boxes.dropFirst(i + 1) { #expect(!a.intersects(b), "\(name): \(a) and \(b) overlap") }
            }
            for r in [layout.board] + boxes {
                #expect([r.minX, r.minY, r.width, r.height].allSatisfy { $0 == $0.rounded() }, "\(name): \(r) on whole pixels")
            }
            #expect((layout.title != nil) == name.contains("title true") && (layout.note != nil) == name.contains("note true"))
        }
    }

    /// 9:16 and the PNG: the pitch fills the width (less a 40 px margin at 1080); 1:1: it fills the height under the
    /// band; 16:9 (D-63): upright in the middle, the title to its left and the note to its right.
    @Test func eachCanvasPlacesThePitchItsWay() throws {
        for kind in Pitch.Kind.allCases {
            let tall = ExportLayout.make(.vertical, kind: kind, showsTitle: true, showsNote: true)
            #expect(tall.canvas == CGSize(width: 1080, height: 1920))
            // Full width less the margins; the long 5-a-side pitch gives up 2.5% of it to keep the note band.
            let wide = kind == .fiveASide ? 0.97 : 0.999
            #expect(tall.pitch(kind).width >= 1000 * wide, "\(kind): \(tall.pitch(kind))")
            let image = ExportLayout.make(.image(width: 804), kind: kind, showsTitle: true, showsNote: true)
            #expect(image.canvas.width == 804 && image.pitch(kind).width >= 744 * wide, "\(kind): \(image.pitch(kind))")

            let square = ExportLayout.make(.square, kind: kind, showsTitle: true, showsNote: true)
            #expect(square.canvas == CGSize(width: 1080, height: 1080))
            #expect(abs(square.pitch(kind).height - square.board.height) < 1, "\(kind)")
            #expect(try #require(square.note).rect.maxY <= square.pitch(kind).minY)

            let landscape = ExportLayout.make(.wide, kind: kind, showsTitle: true, showsNote: true)
            let pitch = landscape.pitch(kind)
            #expect(landscape.canvas == CGSize(width: 1920, height: 1080))
            #expect(abs(pitch.midX - 960) <= 1 && pitch.height >= 999, "\(kind): \(pitch)")
            #expect(try #require(landscape.title).rect.maxX < pitch.minX)
            #expect(try #require(landscape.note).rect.minX > pitch.maxX)
        }
    }

    /// The longest note (140 characters) and a long title fit their boxes at or above the smallest size.
    @Test func longTextFits() {
        let note = String(repeating: "Overlap, cut inside, ", count: 7).prefix(Step.maxNoteLength)
        let title = "Overlap down the left and a third-man run"
        for (name, layout, _) in Self.layouts() {
            if let box = layout.note {
                let size = ExportText.fittedSize(String(note), face: .note, in: box)
                #expect(ExportText.height(String(note), face: .note, size: size, width: box.rect.width) <= box.rect.height,
                        "\(name): note at \(size)")
            }
            if let box = layout.title {
                let size = ExportText.fittedSize(title, face: .title, in: box)
                #expect(ExportText.height(title, face: .title, size: size, width: box.rect.width) <= box.rect.height,
                        "\(name): title at \(size)")
            }
        }
    }

    /// D-07: the board in a frame is `BoardRenderer`'s bitmap of the same state and size, pixel for pixel.
    @Test(arguments: canvases)
    func theBoardIsTheRenderersOwnDrawing(canvas: ExportCanvas) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = ExportFrame(tactic: hero, canvas: canvas, showsTitle: true, showsNotes: true)
        let state = Timeline.state(at: 2.4, in: hero)
        let image = try #require(frame.image(state: state))
        let board = frame.layout.board
        let crop = try #require(image.cropping(to: board))
        let own = try #require(BoardRenderer.image(state: state, tactic: hero, size: board.size))
        let share = VideoReader.share(try VideoReader.bgra(crop), try VideoReader.bgra(own), within: 1)
        #expect(share == 1, "\(canvas): \(share)")
    }

    /// D-38: the corner mark is drawn in its box on the first and the last frame, on every canvas.
    @Test(arguments: canvases)
    func everyFrameCarriesTheMark(canvas: ExportCanvas) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = ExportFrame(tactic: hero, canvas: canvas, showsTitle: false, showsNotes: false)
        for t in [0, frame.duration] {
            let image = try #require(frame.image(at: t))
            #expect(try Self.inkShare(image, in: frame.layout.mark.rect) > 0.02, "\(canvas) at \(t)")
        }
    }

    /// The title and the step's note are drawn when on, and the band is empty when off.
    @Test func theTitleAndNoteFollowTheirSwitches() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let on = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true)
        let off = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: false, showsNotes: false)
        let t = Timeline.duration(of: try #require(hero.phases.first))  // the last step has a note
        let note = try #require(on.layout.note).rect, title = try #require(on.layout.title).rect
        #expect(try Self.inkShare(try #require(on.image(at: t)), in: note) > 0.01)
        #expect(try Self.inkShare(try #require(on.image(at: t)), in: title) > 0.01)
        let empty = try Self.inkShare(try #require(off.image(at: t)), in: title.union(note))
        #expect(empty == 0, "\(empty)")
    }

    /// Frames are a pure function of t: drawn twice, they are the same bytes.
    @Test func framesAreTheSameEveryTime() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true, spotlight: "h3")
        let again = ExportFrame(tactic: hero, canvas: .vertical, showsTitle: true, showsNotes: true, spotlight: "h3")
        for t in [0, 1.1, 3.3, 6.5] {
            let a = try VideoReader.bgra(try #require(frame.image(at: t)))
            let b = try VideoReader.bgra(try #require(again.image(at: t)))
            #expect(a == b, "t = \(t)")
        }
    }

    /// The share of pixels in `rect` that are not the background.
    static func inkShare(_ image: CGImage, in rect: CGRect) throws -> Double {
        let crop = try #require(image.cropping(to: rect))
        let bytes = try VideoReader.bgra(crop)
        let bg = Tokens.Colour.bg
        let ink = stride(from: 0, to: bytes.count, by: 4).filter { i in
            abs(Int(bytes[i + 2]) - Int((bg.red * 255).rounded())) > 8 || abs(Int(bytes[i]) - Int((bg.blue * 255).rounded())) > 8
        }.count
        return Double(ink) / Double(bytes.count / 4)
    }
}
