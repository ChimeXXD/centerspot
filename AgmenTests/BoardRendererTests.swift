import CoreGraphics
import Foundation
import Testing
@testable import Agmen

/// The hero's step 1 drawn offscreen by `BoardRenderer` (D-07), checked by sampling pixels (SPEC §4, D-15).
struct BoardRendererTests {
    static let size = CGSize(width: 334, height: 516)
    static let scale: CGFloat = 3

    struct Frame {
        let geometry: BoardGeometry
        let state: BoardState
        let pixels: [UInt8]
        let width: Int

        /// The colour at a point (in board points), read from the bitmap.
        func colour(at p: CGPoint) -> (r: Int, g: Int, b: Int) {
            let x = Int((p.x * BoardRendererTests.scale).rounded(.down)), y = Int((p.y * BoardRendererTests.scale).rounded(.down))
            let i = (y * width + x) * 4
            return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
        }

        func centre(_ id: String) throws -> CGPoint { geometry.point(try #require(state.positions[id])) }
        var r: CGFloat { geometry.tokenRadius }
    }

    static func render(_ tactic: Tactic, step: Int = 0, options: BoardRenderer.Options = .init()) throws -> Frame {
        try render(tactic, state: Timeline.restingState(step: step, in: tactic), options: options)
    }

    static func render(_ tactic: Tactic, state: BoardState, options: BoardRenderer.Options = .init()) throws -> Frame {
        let image = try #require(BoardRenderer.image(state: state, tactic: tactic, size: size, scale: scale, options: options))
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let geometry = BoardGeometry(kind: tactic.pitch.kind, fitting: CGRect(origin: .zero, size: size))
        return Frame(geometry: geometry, state: state, pixels: pixels, width: w)
    }

    static func close(_ c: (r: Int, g: Int, b: Int), _ expected: RGBA, within tolerance: Int = 3) -> Bool {
        let e = (Int((expected.red * 255).rounded()), Int((expected.green * 255).rounded()), Int((expected.blue * 255).rounded()))
        return abs(c.r - e.0) <= tolerance && abs(c.g - e.1) <= tolerance && abs(c.b - e.2) <= tolerance
    }

    @Test func homeDiscsAreFilledWithTheirKit() throws {
        let frame = try Self.render(try Fixtures.tactic("overlap-left"))
        let six = try frame.centre("h6")
        // Above the number, inside the disc.
        let sample = frame.colour(at: CGPoint(x: six.x, y: six.y - frame.r * 0.75))
        #expect(Self.close(sample, Tokens.kit(.lime).fill), "got \(sample)")
    }

    @Test func emptyPitchShowsItsStripes() throws {
        let frame = try Self.render(try Fixtures.tactic("overlap-left"))
        let bandB = frame.colour(at: frame.geometry.point(Point(x: 0.9, y: 0.42)))  // 6th band from the top
        let bandA = frame.colour(at: frame.geometry.point(Point(x: 0.9, y: 0.55)))  // 5th band
        #expect(Self.close(bandB, Tokens.Colour.bcPitchB, within: 2), "got \(bandB)")
        #expect(Self.close(bandA, Tokens.Colour.bcPitchA, within: 2), "got \(bandA)")
    }

    @Test func selectionIsAWhiteChalkRing() throws {
        let frame = try Self.render(try Fixtures.tactic("overlap-left"), options: .init(selection: "h3"))
        let three = try frame.centre("h3")
        let ring = frame.colour(at: CGPoint(x: three.x + frame.r * 1.45, y: three.y))
        #expect(Self.close(ring, Tokens.Colour.text, within: 8), "got \(ring)")
        let unselected = try Self.render(try Fixtures.tactic("overlap-left"))
        #expect(!Self.close(unselected.colour(at: CGPoint(x: three.x + frame.r * 1.45, y: three.y)), Tokens.Colour.text, within: 40))
    }

    @Test func aBlackKitGetsItsOutline() throws {
        var hero = try Fixtures.tactic("overlap-left")
        hero.sides[0].colour = .black
        let frame = try Self.render(hero)
        let six = try frame.centre("h6")
        let edge = frame.colour(at: CGPoint(x: six.x + frame.r * 0.95, y: six.y))
        let outline = try #require(Tokens.kit(.black).outline)
        #expect(Self.close(edge, outline, within: 12), "got \(edge)")
        #expect(Self.close(frame.colour(at: CGPoint(x: six.x, y: six.y - frame.r * 0.75)), Tokens.kit(.black).fill))
    }

    @Test func awayPlayersAreRingsWithADarkCentre() throws {
        let frame = try Self.render(try Fixtures.tactic("overlap-left"))
        let keeper = try frame.centre("a1")
        let ring = frame.colour(at: CGPoint(x: keeper.x + frame.r * 0.9, y: keeper.y))
        #expect(Self.close(ring, Tokens.kit(.coral).fill, within: 8), "got \(ring)")
        let inside = frame.colour(at: CGPoint(x: keeper.x - frame.r * 0.55, y: keeper.y - frame.r * 0.5))
        #expect(inside.r < 40 && inside.g < 50 && inside.b < 40, "got \(inside)")
    }

    @Test func thePassIsDashed() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let frame = try Self.render(hero)
        let pass = try #require(hero.phases[0].steps[0].arrows.first { $0.kind == .pass })
        let a = frame.geometry.point(pass.points[0]), b = frame.geometry.point(pass.points[1])
        var lime = 0, gaps = 0
        for i in 0...60 {
            let t = 0.62 + 0.18 * CGFloat(i) / 60  // clear of their 7, before the head
            let c = frame.colour(at: CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            if Self.close(c, Tokens.Colour.pass, within: 30) { lime += 1 }
            if c.g < 60 { gaps += 1 }
        }
        #expect(lime > 10 && gaps > 3, "lime \(lime), gaps \(gaps)")
    }
}
