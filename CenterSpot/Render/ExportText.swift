import CoreGraphics
import CoreText
import Foundation

/// Text in exports (UI-BRIEF §1 rule 6): the title and the corner mark in heavy Nunito, step notes in Kalam (the
/// coach's voice). Text shrinks to fit its box, so a 140-character note never runs into the pitch.
enum ExportText {
    enum Face: Sendable {
        case title, note, mark
    }

    static func font(_ face: Face, size: CGFloat) -> CTFont {
        switch face {
        case .title:
            return TokenDrawing.numberFont(size: size)
        case .mark:
            return TokenDrawing.numberFont(size: size, weight: TokenDrawing.wordmarkWeight)
        case .note:
            let font = CTFontCreateWithName(Tokens.Typeface.noteFullName as CFString, size, nil)
            if (CTFontCopyFamilyName(font) as String).hasPrefix(Tokens.Typeface.noteName) { return font }
            return CTFontCreateUIFontForLanguage(.system, size, nil) ?? font
        }
    }

    /// A framesetter for `text` in `face` at `size`, in `colour`, aligned left or right.
    static func framesetter(_ text: String, face: Face, size: CGFloat, colour: CGColor,
                            alignment: CTTextAlignment = .left) -> CTFramesetter {
        var align = alignment
        let style = withUnsafeBytes(of: &align) { bytes in
            var setting = CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size,
                                                  value: bytes.baseAddress!)
            return CTParagraphStyleCreate(&setting, 1)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(face, size: size),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): colour,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): style,
        ]
        return CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// The height `text` needs at `size` when wrapped to `width`.
    static func height(_ text: String, face: Face, size: CGFloat, width: CGFloat) -> CGFloat {
        let setter = framesetter(text, face: face, size: size, colour: Tokens.Colour.text.cgColor)
        return CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil,
                                                            CGSize(width: width, height: .greatestFiniteMagnitude), nil).height
    }

    /// The largest whole size from the box's maximum down to its minimum at which `text` fits; the minimum if none does.
    static func fittedSize(_ text: String, face: Face, in box: ExportLayout.TextBox) -> CGFloat {
        var size = box.maxSize.rounded(.down)
        while size > box.minSize, height(text, face: face, size: size, width: box.rect.width) > box.rect.height {
            size -= 1
        }
        return max(size, box.minSize)
    }

    /// `text` laid out in `rect` from the top, in a y-down context. Lines that don't fit are left out.
    static func frame(_ text: String, face: Face, size: CGFloat, colour: CGColor, in rect: CGRect,
                      alignment: CTTextAlignment = .left) -> CTFrame {
        let setter = framesetter(text, face: face, size: size, colour: colour, alignment: alignment)
        let path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
        return CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
    }

    /// Draws a laid-out frame at `rect` in a y-down context (CoreText lays out y-up, so it is flipped here).
    static func draw(_ frame: CTFrame, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame, ctx)
        ctx.restoreGState()
    }
}
