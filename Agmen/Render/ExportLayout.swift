import CoreGraphics
import Foundation

/// What an export is drawn on: one of the video sizes (D-11, D-63) or the PNG of a step, whose pixel width is twice
/// the board's on-screen width in points (SPEC §7).
enum ExportCanvas: Sendable, Hashable {
    case vertical, square, wide
    case image(width: Int)
}

/// Where each part of an export frame goes, in pixels, y down (SPEC §7, D-63): the board (`BoardRenderer` fits the
/// pitch inside it, D-07), the title band, the current step's note and the "Agmen" corner mark (D-38). The mark sits
/// outside the pitch on every canvas, so it never covers play. Rects are whole pixels, so the board lands on the same
/// pixel grid as a bitmap of its own (`ExportFrameTests`). Caption safe zones are not part of it (preview only, D-11).
struct ExportLayout: Sendable, Equatable {
    /// A text area and the largest and smallest font sizes it may use (text shrinks to fit).
    struct TextBox: Sendable, Equatable {
        var rect: CGRect
        var maxSize: CGFloat
        var minSize: CGFloat
    }

    var canvas: CGSize
    var board: CGRect
    var title: TextBox?
    var note: TextBox?
    var mark: TextBox

    /// The pitch inside `board`, as `BoardRenderer` will draw it.
    func pitch(_ kind: Pitch.Kind) -> CGRect { BoardGeometry(kind: kind, fitting: board).pitchRect }

    /// - Parameter broadcast: the board is the broadcast camera's view (BR-2, the mockup's export frames): edge to edge
    ///   under the text band on 9:16 and 1:1, the whole frame on 16:9, with the text and mark drawn over it. The text
    ///   and mark keep their places.
    static func make(_ canvas: ExportCanvas, kind: Pitch.Kind, showsTitle: Bool, showsNote: Bool,
                     broadcast: Bool = false) -> ExportLayout {
        var layout = make(canvas, kind: kind, showsTitle: showsTitle, showsNote: showsNote)
        guard broadcast else { return layout }
        if case .wide = canvas {
            layout.board = CGRect(origin: .zero, size: layout.canvas)
        } else {
            layout.board = CGRect(x: 0, y: layout.board.minY, width: layout.canvas.width, height: layout.board.height)
        }
        return layout
    }

    private static func make(_ canvas: ExportCanvas, kind: Pitch.Kind, showsTitle: Bool, showsNote: Bool) -> ExportLayout {
        let aspect = CGFloat(kind.size.length / kind.size.width)
        switch canvas {
        case .vertical: return portrait(width: 1080, fixedHeight: true, aspect: aspect, title: showsTitle, note: showsNote)
        case .image(let width):
            return portrait(width: CGFloat(max(width, 1)), fixedHeight: false, aspect: aspect, title: showsTitle, note: showsNote)
        case .square: return square(title: showsTitle, note: showsNote)
        case .wide: return wide(title: showsTitle, note: showsNote)
        }
    }

    /// Space kept between text and the pitch at 1080 wide: a player on the goal line, ringed, reaches 1.61 disc radii
    /// (61 px) past the pitch's edge.
    static let clearance: CGFloat = 64

    /// 9:16 and the PNG: the pitch fills the width; title and note in the band above it; the mark in a strip under it.
    /// Drawn at 1080 wide and scaled; 9:16 is always 1920 tall, the PNG as tall as its pitch needs.
    private static func portrait(width: CGFloat, fixedHeight: Bool, aspect: CGFloat, title: Bool, note: Bool) -> ExportLayout {
        let u = width / 1080, margin: CGFloat = 40, strip: CGFloat = 96
        // A 5-a-side pitch (1.6 long) would leave too little band for a long note, so it gets a little narrower.
        let pitchHeight = min((1080 - 2 * margin) * aspect, 1920 - strip - 264)
        let height = fixedHeight ? 1920 : (280 + pitchHeight + strip)
        let band = height - strip - pitchHeight  // 280 on a full pitch
        let board = CGRect(x: margin, y: band, width: 1080 - 2 * margin, height: pitchHeight)
        let (t, n) = stack(in: CGRect(x: margin, y: 36, width: 1080 - 2 * margin, height: band - 36 - clearance),
                           title: title, note: note, titleSize: 54, noteSize: 42)
        let mark = TextBox(rect: CGRect(x: 1080 - margin - 320, y: height - strip + 22, width: 320, height: 52),
                           maxSize: 36, minSize: 36)
        return ExportLayout(canvas: CGSize(width: 1080, height: height), board: board, title: t, note: n, mark: mark)
            .scaled(by: u)
    }

    /// 1:1: the pitch fills the height under a title and note band; the mark in the corner beside it, outside the board.
    private static func square(title: Bool, note: Bool) -> ExportLayout {
        let band: CGFloat = 196
        let (t, n) = stack(in: CGRect(x: 40, y: 24, width: 1000, height: band - 24 - 36), title: title, note: note,
                           titleSize: 46, noteSize: 36)
        return ExportLayout(canvas: CGSize(width: 1080, height: 1080),
                            board: CGRect(x: 230, y: band, width: 620, height: 1080 - band - 40),
                            title: t, note: n,
                            mark: TextBox(rect: CGRect(x: 840, y: 1000, width: 200, height: 48), maxSize: 32, minSize: 32))
            .scaled(by: 1)
    }

    /// 16:9 (D-63): the pitch upright in the middle, the title on the left, the step note on the right.
    private static func wide(title: Bool, note: Bool) -> ExportLayout {
        ExportLayout(canvas: CGSize(width: 1920, height: 1080),
                     board: CGRect(x: 600, y: 40, width: 720, height: 1000),
                     title: title ? TextBox(rect: CGRect(x: 64, y: 72, width: 500, height: 560), maxSize: 64, minSize: 34) : nil,
                     note: note ? TextBox(rect: CGRect(x: 1356, y: 72, width: 500, height: 640), maxSize: 52, minSize: 28) : nil,
                     mark: TextBox(rect: CGRect(x: 1640, y: 1004, width: 240, height: 52), maxSize: 36, minSize: 36))
            .scaled(by: 1)
    }

    /// Title over note in `band`; either alone takes the whole band.
    private static func stack(in band: CGRect, title: Bool, note: Bool, titleSize: CGFloat,
                              noteSize: CGFloat) -> (TextBox?, TextBox?) {
        let titleHeight = (titleSize * 1.3).rounded()
        switch (title, note) {
        case (true, true):
            let gap = (titleSize * 0.15).rounded()
            let t = TextBox(rect: CGRect(x: band.minX, y: band.minY, width: band.width, height: titleHeight),
                            maxSize: titleSize, minSize: titleSize * 0.6)
            let n = TextBox(rect: CGRect(x: band.minX, y: band.minY + titleHeight + gap, width: band.width,
                                         height: band.height - titleHeight - gap),
                            maxSize: noteSize, minSize: noteSize * 0.55)
            return (t, n)
        case (true, false):
            return (TextBox(rect: band, maxSize: titleSize, minSize: titleSize * 0.6), nil)
        case (false, true):
            return (nil, TextBox(rect: band, maxSize: noteSize, minSize: noteSize * 0.55))
        case (false, false):
            return (nil, nil)
        }
    }

    /// Every rect and size times `u`, rects snapped to whole pixels.
    private func scaled(by u: CGFloat) -> ExportLayout {
        func px(_ r: CGRect) -> CGRect {
            let x = (r.minX * u).rounded(), y = (r.minY * u).rounded()
            return CGRect(x: x, y: y, width: (r.maxX * u).rounded() - x, height: (r.maxY * u).rounded() - y)
        }
        func box(_ b: TextBox) -> TextBox { TextBox(rect: px(b.rect), maxSize: b.maxSize * u, minSize: b.minSize * u) }
        return ExportLayout(canvas: CGSize(width: (canvas.width * u).rounded(), height: (canvas.height * u).rounded()),
                            board: px(board), title: title.map(box), note: note.map(box), mark: box(mark))
    }
}
