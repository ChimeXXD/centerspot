import CoreGraphics
import SwiftUI
import Testing
@testable import Agmen

/// D4-3, D-07, D-60, D-61: the board on screen and an exported frame at the same `t` and size agree on at least 99.5%
/// of pixels within 16/255 per channel, and no pixel is more than 64/255 off in any channel. The screen side is the real board view (`BoardCanvas`: `Canvas` +
/// `withCGContext`) captured with `ImageRenderer`, not a second offscreen call.
///
/// Why 16 (D-60 supersedes D-24's 2/255): fills match exactly, but SwiftUI rasterizes the `withCGContext` recording
/// with its own anti-aliasing, so line edges differ from CoreGraphics' (an edge pixel 0.32 covered instead of 0.376,
/// up to ~12/255 apart). At 2/255 the bare pitch was 98.5%. Why the 64 cap (D-61): a share rule alone can't see one
/// token drawn 2 px off (about 0.07% of the frame); a displaced or recoloured token moves some pixel far past 64.
@MainActor
struct RendererParityTests {
    /// A full pitch's aspect exactly (340 × 525), so neither side has margins.
    static let size = CGSize(width: 340, height: 525)
    static let scale: CGFloat = 2
    /// D-60 and D-61's numbers; changing them needs Chime's OK.
    nonisolated static let channelTolerance = 16
    nonisolated static let requiredShare = 0.995
    nonisolated static let maxChannelDifference = 64

    struct Comparison: CustomStringConvertible {
        let share: Double
        /// The largest difference in any channel, and the pixel (x, y from the top left) where it is.
        let worst: Int
        let worstAt: (x: Int, y: Int)
        let count: Int

        var passes: Bool { share >= requiredShare && worst <= maxChannelDifference }

        var description: String {
            "\(String(format: "%.4f", share * 100))% of \(count) px within \(channelTolerance)/255 (needs "
                + "\(String(format: "%.1f", requiredShare * 100))%); max channel diff \(worst)/255 at x \(worstAt.x), "
                + "y \(worstAt.y) (cap \(maxChannelDifference))"
        }
    }

    /// The board view as the screen lays it out, on the screen's background, rendered by SwiftUI.
    static func screen(_ tactic: Tactic, _ state: BoardState) throws -> CGImage {
        let view = BoardCanvas(tactic: tactic, state: state, selection: nil,
                               onTap: { _ in }, onDoubleTap: { _ in }, onDrag: { _, _ in }, onDragEnd: { _, _ in },
                               onNudge: { _, _ in })
            .frame(width: size.width, height: size.height)
            .background(Tokens.Colour.bg.color)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        return try #require(renderer.cgImage)
    }

    static func export(_ tactic: Tactic, _ state: BoardState) throws -> CGImage {
        try #require(BoardRenderer.image(state: state, tactic: tactic, size: size, scale: scale))
    }

    /// Both images redrawn into the same sRGB RGBA8 buffer layout, then compared channel by channel.
    static func compare(_ a: CGImage, _ b: CGImage) throws -> Comparison {
        #expect(a.width == b.width && a.height == b.height, "\(a.width)×\(a.height) vs \(b.width)×\(b.height)")
        let w = b.width, h = b.height
        let pa = try pixels(a, w, h), pb = try pixels(b, w, h)
        var within = 0, worst = 0, worstAt = (x: 0, y: 0)
        for i in 0..<(w * h) {
            var off = 0
            for c in 0..<3 { off = max(off, abs(Int(pa[i * 4 + c]) - Int(pb[i * 4 + c]))) }
            if off > worst { worst = off; worstAt = (i % w, i / w) }
            if off <= channelTolerance { within += 1 }
        }
        return Comparison(share: Double(within) / Double(w * h), worst: worst, worstAt: worstAt, count: w * h)
    }

    private static func pixels(_ image: CGImage, _ w: Int, _ h: Int) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try pixels.withUnsafeMutableBytes { buffer in
            let ctx = try #require(CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return pixels
    }

    /// SPEC §10's cheapest test first: the pitch with nothing on it, both styles.
    @Test(arguments: Pitch.Style.allCases)
    func thePitchAloneMatches(style: Pitch.Style) throws {
        var pitch = try Fixtures.tactic("overlap-left")
        pitch.pitch.style = style
        for id in pitch.tokens.map(\.id) { TacticEdits.deleteToken(id, in: &pitch) }
        for s in pitch.phases[0].steps.indices { pitch.phases[0].steps[s].arrows = [] }
        let state = Timeline.restingState(step: 0, in: pitch)
        let result = try Self.compare(Self.screen(pitch, state), Self.export(pitch, state))
        #expect(result.passes, "\(result)")
    }

    /// The hero mid-move: tokens between steps, the ball with its carrier, arrows fading.
    @Test(arguments: [0.9, 2.4, 3.9, 5.5])
    func theHeroMatchesMidMove(t: Double) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: t, in: hero)
        let result = try Self.compare(Self.screen(hero, state), Self.export(hero, state))
        #expect(result.passes, "t = \(t): \(result)")
    }

    /// D-65: step 4's zone, line, rings and heat fading in, shown mid-move and fading out, through the one renderer.
    @Test(arguments: [4.8, 5.5, 6.1])
    func theHerosMarksMatch(t: Double) throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: t, in: hero)
        #expect(state.marks.count == 4, "step 4's marks are on screen at \(t)")
        let result = try Self.compare(Self.screen(hero, state), Self.export(hero, state))
        #expect(result.passes, "t = \(t): \(result)")
    }

    /// Not blind to marks: the export without step 4's heat fails against the screen with it.
    @Test func aMissingMarkFails() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: 5.5, in: hero)
        var noHeat = state
        noHeat.marks.removeAll { $0.id == "g2" }
        let result = try Self.compare(Self.screen(hero, state), Self.export(hero, noHeat))
        #expect(!result.passes, "\(result)")
    }

    /// The comparison is not blind: a different instant of the same move fails it.
    @Test func aDifferentInstantDoesNotMatch() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let result = try Self.compare(Self.screen(hero, Timeline.state(at: 0.9, in: hero)),
                                      Self.export(hero, Timeline.state(at: 3.9, in: hero)))
        #expect(!result.passes, "\(result)")
    }

    /// D-61, kept as tests: one token drawn 2 px (1 pt at scale 2) off fails, though the share alone would pass it.
    @Test func oneTokenTwoPixelsOffFails() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: 2.4, in: hero)
        var shifted = state
        let three = try #require(state.positions["h3"])
        shifted.positions["h3"] = Point(x: three.x + 1 / Self.size.width, y: three.y)
        let result = try Self.compare(Self.screen(hero, state), Self.export(hero, shifted))
        #expect(!result.passes, "\(result)")
        #expect(result.worst > Self.maxChannelDifference, "the cap catches it: \(result)")
    }

    /// D-61: one token in the wrong colour fails (an away ring drawn as a home disc).
    @Test func oneRecolouredTokenFails() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let state = Timeline.state(at: 2.4, in: hero)
        var recoloured = hero
        let i = try #require(recoloured.tokens.firstIndex { $0.id == "a5" })
        recoloured.tokens[i].side = .home
        let result = try Self.compare(Self.screen(hero, state), Self.export(recoloured, state))
        #expect(!result.passes, "\(result)")
    }
}
