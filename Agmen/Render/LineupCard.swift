import CoreGraphics
import CoreText
import Foundation

/// The lineup card (D-63 Should): a team sheet of step 1. The title, the shape's name, our side on the pitch (drawn by
/// `BoardRenderer`, D-07) and a list of number and name, sorted by shirt number, with the discs drawn by
/// `TokenDrawing`; the "Agmen" corner mark (D-38). 1080 × 1350, the 4:5 of a feed post.
struct LineupCard {
    static let size = CGSize(width: 1080, height: 1350)
    /// The list column, right of the pitch.
    static let listRect = CGRect(x: 640, y: 210, width: 400, height: 1060)
    static let boardRect = CGRect(x: 40, y: 210, width: 560, height: 1060)
    static let titleBox = ExportLayout.TextBox(rect: CGRect(x: 56, y: 52, width: 968, height: 80), maxSize: 56, minSize: 32)
    static let shapeBox = ExportLayout.TextBox(rect: CGRect(x: 56, y: 138, width: 968, height: 48), maxSize: 30, minSize: 30)
    static let markBox = ExportLayout.TextBox(rect: CGRect(x: 820, y: 1290, width: 220, height: 48), maxSize: 32, minSize: 32)
    /// Names shrink together until the longest fits its row (on up to two lines), down to the smallest size.
    static let nameSizes: ClosedRange<CGFloat> = 16...34

    struct Row: Equatable {
        let tokenID: String
        let number: Int?
        let name: String
        let rect: CGRect
        /// Where the name goes, right of the disc.
        let nameRect: CGRect
        let disc: CGPoint
        let discRadius: CGFloat
    }

    /// Our side only, on step 1, without the ball or arrows: the team sheet, not the move.
    let tactic: Tactic
    let rows: [Row]
    let nameSize: CGFloat
    let shape: String

    init(_ source: Tactic, formations: [Formation] = Presets.shared.formations) {
        var home = source
        home.tokens = source.tokens.filter { $0.kind == .player && $0.side == .home }
        tactic = home
        let players = home.tokens.enumerated().sorted { a, b in
            (a.element.number ?? .max, a.offset) < (b.element.number ?? .max, b.offset)
        }.map(\.element)
        let height = min(96, Self.listRect.height / CGFloat(max(players.count, 1)))
        let radius = (height * 0.32).rounded()
        var rows: [Row] = []
        for (i, player) in players.enumerated() {
            let rect = CGRect(x: Self.listRect.minX, y: Self.listRect.minY + CGFloat(i) * height,
                              width: Self.listRect.width, height: height)
            let nameX = rect.minX + 2 * radius + 24
            rows.append(Row(tokenID: player.id, number: player.number, name: Self.label(player), rect: rect,
                            nameRect: CGRect(x: nameX, y: rect.minY, width: rect.maxX - nameX, height: height),
                            disc: CGPoint(x: rect.minX + radius + 4, y: rect.midY), discRadius: radius))
        }
        self.rows = rows
        let largest = min(Self.nameSizes.upperBound, (height * 0.36).rounded())
        nameSize = rows.map { row in
            ExportText.fittedSize(row.name, face: .title,
                                  in: ExportLayout.TextBox(rect: row.nameRect, maxSize: largest, minSize: Self.nameSizes.lowerBound))
        }.min() ?? largest
        shape = FormationMatch.formation(of: home, in: formations)?.name ?? "\(home.tokens.count) players"
    }

    /// "Ade", else the role ("Striker"), else "Player".
    static func label(_ token: Token) -> String {
        if let name = token.name?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return name }
        return Presets.shared.role(token.roleID)?.name ?? "Player"
    }

    func draw(in ctx: CGContext) {
        ctx.setFillColor(Tokens.Colour.bg.cgColor)
        ctx.fill(CGRect(origin: .zero, size: Self.size))
        text(tactic.title, box: Self.titleBox, colour: Tokens.Colour.text, ctx: ctx)
        text(shape, box: Self.shapeBox, colour: Tokens.Colour.muted, ctx: ctx)

        var state = Timeline.restingState(step: 0, in: tactic)
        state.arrows = []
        let board = CGRect(x: Self.boardRect.minX, y: Self.boardRect.minY, width: Self.boardRect.width,
                           height: min(Self.boardRect.height, BoardGeometry.height(forWidth: Self.boardRect.width, kind: tactic.pitch.kind)))
        BoardRenderer.draw(state: state, tactic: tactic, in: ctx, rect: board)

        for row in rows {
            guard let token = tactic.tokens.first(where: { $0.id == row.tokenID }) else { continue }
            TokenDrawing.draw(token, at: row.disc, kit: BoardRenderer.kit(for: token, in: tactic), radius: row.discRadius,
                              style: .init(), in: ctx)
            // Centred in the row: one line, or two for a long name.
            let height = min(ExportText.height(row.name, face: .title, size: nameSize, width: row.nameRect.width).rounded(.up),
                             row.nameRect.height)
            let box = CGRect(x: row.nameRect.minX, y: row.nameRect.midY - height / 2, width: row.nameRect.width, height: height)
            ExportText.draw(ExportText.frame(row.name, face: .title, size: nameSize, colour: Tokens.Colour.text.cgColor, in: box),
                            in: box, ctx: ctx)
        }
        text(ExportFrame.mark, box: Self.markBox, colour: Tokens.Colour.muted, ctx: ctx, alignment: .right)
    }

    func image() -> CGImage? {
        guard let ctx = ExportFrame.bitmap(Self.size) else { return nil }
        draw(in: ctx)
        return ctx.makeImage()
    }

    private func text(_ string: String, box: ExportLayout.TextBox, colour: RGBA, ctx: CGContext,
                      alignment: CTTextAlignment = .left) {
        let size = ExportText.fittedSize(string, face: .title, in: box)
        ExportText.draw(ExportText.frame(string, face: .title, size: size, colour: colour.cgColor, in: box.rect,
                                         alignment: alignment), in: box.rect, ctx: ctx)
    }
}
