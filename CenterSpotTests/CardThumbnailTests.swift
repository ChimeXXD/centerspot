import CoreGraphics
import Foundation
import Testing
@testable import CenterSpot

/// D-74: library cards draw the whole pitch turned sideways (attacking right) with the one `BoardRenderer` (D-07),
/// discs 1.5 times the board's, and numbers only when they come out at 7 pt or more.
struct CardThumbnailTests {
    static let scale: CGFloat = 3

    /// An image's RGBA8 pixels, y-down.
    struct Pixels {
        let width: Int, height: Int
        let bytes: [UInt8]

        init(_ image: CGImage) throws {
            width = image.width
            height = image.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let (w, h) = (width, height)
            try bytes.withUnsafeMutableBytes { buffer in
                let ctx = try #require(CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                                 bytesPerRow: w * 4, space: space,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
            self.bytes = bytes
        }

        func rgb(_ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
            let i = (y * width + x) * 4
            return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
        }

        /// The colour at a point in the image's points (at `CardThumbnailTests.scale`).
        func rgb(at p: CGPoint) -> (r: Int, g: Int, b: Int) {
            rgb(Int((p.x * CardThumbnailTests.scale).rounded(.down)), Int((p.y * CardThumbnailTests.scale).rounded(.down)))
        }
    }

    /// The hero's step 1 without the ball: the ball's offset at its carrier's feet stays down-right on a card, as in
    /// the mockup, so it is the one part a plain turn doesn't reproduce.
    static func heroWithoutBall() throws -> (Tactic, BoardState) {
        let tactic = try Fixtures.tactic("overlap-left")
        var state = Timeline.restingState(step: 0, in: tactic)
        for token in tactic.tokens where token.kind == .ball { state.positions[token.id] = nil }
        return (tactic, state)
    }

    static func image(_ tactic: Tactic, _ state: BoardState, size: CGSize, card: CardStyle) throws -> CGImage {
        try #require(BoardRenderer.image(state: state, tactic: tactic, size: size, scale: scale, options: .init(card: card)))
    }

    /// The card's upright drawing (same sizes, not turned).
    static var upright: CardStyle {
        var style = CardStyle.card
        style.sideways = false
        return style
    }

    // MARK: The turn

    /// The sideways card equals the upright card turned a quarter clockwise, pixel for pixel within D-60 / D-61's
    /// tolerances, at the iPhone card's size (no numbers there, so nothing on it should stay upright).
    @Test func theSidewaysCardIsTheBoardTurnedAQuarterClockwise() throws {
        let (tactic, state) = try Self.heroWithoutBall()
        let size = CGSize(width: 92, height: 60)
        #expect(!CardStyle.card.showsNumbers(pitchLength: size.width), "the iPhone card has no numbers")
        let sideways = try Pixels(Self.image(tactic, state, size: size, card: .card))
        let upright = try Pixels(Self.image(tactic, state, size: CGSize(width: size.height, height: size.width), card: Self.upright))
        try #require(sideways.width == upright.height && sideways.height == upright.width)

        // Upright pixel (x, y) lands at (H - 1 - y, x): its top (the opponent's goal) on the right.
        var within = 0, worst = 0
        for y in 0..<upright.height {
            for x in 0..<upright.width {
                let a = upright.rgb(x, y), b = sideways.rgb(upright.height - 1 - y, x)
                let off = max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b))
                worst = max(worst, off)
                if off <= RendererParityTests.channelTolerance { within += 1 }
            }
        }
        let share = Double(within) / Double(upright.width * upright.height)
        #expect(share >= RendererParityTests.requiredShare, "\(share * 100)% within \(RendererParityTests.channelTolerance)/255")
        #expect(worst <= RendererParityTests.maxChannelDifference, "max channel difference \(worst)/255")
    }

    /// A known player lands where the turn puts him: the left-back (3, x 0.15 up the left) near the top left of an iPad
    /// card, never mirrored to the bottom right. Our goal is on the left.
    @Test func ourLeftBackIsTopLeftAndWeAttackRight() throws {
        let (tactic, state) = try Self.heroWithoutBall()
        let size = CGSize(width: 186, height: 120)
        let pixels = try Pixels(Self.image(tactic, state, size: size, card: .card))
        let g = CardStyle.card.geometry(kind: tactic.pitch.kind, in: CGRect(origin: .zero, size: size))
        let three = try #require(state.positions["h3"])
        let pitchLength = g.pitchRect.height, pitchWidth = g.pitchRect.width
        let left = (size.width - pitchLength) / 2, top = (size.height - pitchWidth) / 2
        let expected = CGPoint(x: left + CGFloat(three.y) * pitchLength, y: top + CGFloat(three.x) * pitchWidth)
        let mirrored = CGPoint(x: size.width - expected.x, y: size.height - expected.y)
        // Inside the disc, clear of the number.
        let probe = { (c: CGPoint) in CGPoint(x: c.x, y: c.y - g.tokenRadius * 0.75) }
        let lime = Tokens.kit(.lime).fill
        #expect(BoardRendererTests.close(pixels.rgb(at: probe(expected)), lime, within: 6), "3 at \(expected)")
        #expect(!BoardRendererTests.close(pixels.rgb(at: probe(mirrored)), lime, within: 40), "nothing lime at \(mirrored)")
        #expect(expected.x < size.width / 3 && expected.y < size.height / 3, "3 sits in the top left third")
    }

    /// Discs are 1.5 times the board's: 5.7% of the pitch's short side.
    @Test func discsAreOneAndAHalfTimesTheBoards() {
        let g = CardStyle.card.geometry(kind: .full, in: CGRect(x: 0, y: 0, width: 185.3, height: 120))
        #expect(abs(g.tokenRadius - g.pitchRect.width * 0.057) < 0.001, "\(g.tokenRadius)")
        #expect(abs(g.pitchRect.height - 185.3) < 0.01, "the pitch's length runs across the card")
    }

    // MARK: Numbers

    /// The mockup's thresholds: numbers need a pitch at least 181 pt long. The iPhone card (92.3 pt) has none; the
    /// 13-inch iPad landscape card (185.3 pt) has them at 7.1 pt.
    @Test func numbersNeedAPitchAtLeast181PointsLong() {
        let style = CardStyle.card
        #expect(!style.showsNumbers(pitchLength: 92.3))
        #expect(!style.showsNumbers(pitchLength: 180))
        #expect(style.showsNumbers(pitchLength: 181))
        #expect(style.showsNumbers(pitchLength: 185.3))
    }

    /// Below 7 pt the drawing is exactly the drawing with numbers switched off; at 7 pt and over the numbers are there.
    @Test(arguments: [(CGFloat(180), false), (CGFloat(182), true), (CGFloat(92), false)])
    func numbersAreDroppedBelowSevenPoints(length: CGFloat, drawn: Bool) throws {
        let (tactic, state) = try Self.heroWithoutBall()
        let size = CGSize(width: length, height: (length * 68 / 105).rounded())
        var none = CardStyle.card
        none.minimumNumberSize = .infinity
        let card = try Pixels(Self.image(tactic, state, size: size, card: .card))
        let bare = try Pixels(Self.image(tactic, state, size: size, card: none))
        #expect((card.bytes != bare.bytes) == drawn, "\(length) pt: numbers \(drawn ? "expected" : "not expected")")
    }

    /// Numbers stay upright on a sideways card: a disc with its number reads the same as on the upright card.
    @Test func numbersStayUpright() throws {
        let (tactic, state) = try Self.heroWithoutBall()
        let size = CGSize(width: 186, height: 120)
        let sideways = try Pixels(Self.image(tactic, state, size: size, card: .card))
        let upright = try Pixels(Self.image(tactic, state, size: CGSize(width: size.height, height: size.width), card: Self.upright))
        let g = CardStyle.card.geometry(kind: tactic.pitch.kind, in: CGRect(origin: .zero, size: size))
        let p = try #require(state.positions["h9"])
        let up = g.point(p)
        let turned = up.applying(CardStyle.sidewaysTransform(into: CGRect(origin: .zero, size: size)))
        // Compare the number's box, pixel for pixel, between the two (same sub-pixel phase: integer sizes, exact turn).
        let half = Int((g.tokenRadius * 0.8 * Self.scale).rounded())
        let (ux, uy) = (Int((up.x * Self.scale).rounded()), Int((up.y * Self.scale).rounded()))
        let (sx, sy) = (Int((turned.x * Self.scale).rounded()), Int((turned.y * Self.scale).rounded()))
        var off = 0, total = 0, rotatedOff = 0
        for dy in -half..<half {
            for dx in -half..<half {
                let a = upright.rgb(ux + dx, uy + dy), b = sideways.rgb(sx + dx, sy + dy)
                if max(abs(a.r - b.r), abs(a.g - b.g), abs(a.b - b.b)) > 64 { off += 1 }
                // The same box read turned a quarter: what a turned number would match.
                let c = sideways.rgb(sx - dy - 1, sy + dx)
                if max(abs(a.r - c.r), abs(a.g - c.g), abs(a.b - c.b)) > 64 { rotatedOff += 1 }
                total += 1
            }
        }
        #expect(Double(off) / Double(total) < 0.02, "\(off) of \(total) px differ from the upright number")
        #expect(rotatedOff > off * 3, "a turned number would differ more (\(rotatedOff) px)")
    }

    // MARK: Cost

    /// Thirty cards' thumbnails at an iPhone card's size and the screen's 3x: each must stay well under a frame.
    @Test func thirtyThumbnailsAreCheap() throws {
        let tactic = try Fixtures.tactic("overlap-left")
        let state = Timeline.restingState(step: 0, in: tactic)
        let size = CGSize(width: 124, height: 80)
        let clock = ContinuousClock()
        let elapsed = clock.measure {
            for _ in 0..<30 { _ = BoardRenderer.image(state: state, tactic: tactic, size: size, scale: 3, options: .init(card: .card)) }
        }
        let perCard = elapsed / 30
        print("CENTERSPOT-THUMB 30 cards \(elapsed), \(perCard) each")
        #expect(perCard < .milliseconds(16), "\(perCard) a card")
    }
}
