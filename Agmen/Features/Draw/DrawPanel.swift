import SwiftUI

/// Under the pitch in draw mode (the mockup's "draw", "draw--tools" and "draw--shape-*" screens): the handwritten hint,
/// or the selected mark's row with Remove, then a panel with the Shape switch (D-72: Straight or Curved, for the four
/// arrows) or the picked mark's help line, and two rows of tools: the four arrows that move players (D-59) and the three
/// marks that explain (D-65). At the accessibility sizes all seven sit in one row that
/// scrolls sideways, so the pitch keeps its room (D-70). Each tile draws its line style in its colour, so arrow kinds
/// never differ by colour alone (D-15).
struct DrawPanel: View {
    @Binding var tool: DrawTool
    /// How the next arrow is drawn (D-72).
    @Binding var shape: ArrowShape
    /// "Zone 1 · step 4" for the selected mark (or, in the iPad column, "3's run · drag the dot to bend"), or nil to show
    /// the hint.
    var selectedMark: String?
    var onRemoveMark: () -> Void = {}
    /// The hint in place of the tool's own ("Drag the middle dot to change the bend."), or nil.
    var hint: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The column's tiles are taller (the mockup's 64 pt).
    static let columnTile: CGFloat = 64

    private func columns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s1 + 2), count: count)
    }

    /// iPad landscape (D-73): the mark row and the tools are cards in the right column, the hint under them.
    var inColumn = false

    @ViewBuilder var body: some View {
        if inColumn { columnBody } else { underPitch }
    }

    private var columnBody: some View {
        VStack(spacing: Tokens.Space.s5) {
            if let selectedMark { markRow(selectedMark) }
            tools
                .padding(.horizontal, Tokens.Space.s3 + 2)
                .padding(.vertical, Tokens.Space.s3)
                .background(Tokens.Colour.surface.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.sheet))
            if !dynamicTypeSize.isAccessibilitySize { hintLine }
        }
    }

    private var underPitch: some View {
        VStack(spacing: 0) {
            if let selectedMark {
                markRow(selectedMark)
            } else if !dynamicTypeSize.isAccessibilitySize {
                // At the accessibility sizes the hint would push the pitch down to a thumbnail, so it's left out and the
                // pitch keeps the room (D-68). The help line below names the tool's line, not where to start.
                hintLine
            }
            panel
        }
    }

    private var hintLine: some View {
        Text(hint ?? tool.hint)
            .font(Tokens.Typeface.note)
            .foregroundStyle(Tokens.Colour.muted.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s1 + 2)
            .accessibilityIdentifier("draw.hint")
            .padding(.bottom, Tokens.Space.s3)  // the mockup's draw--shape-*: 6 pt under the pitch, 13 over the panel
    }

    /// The mockup's "Zone 1 · step 4" row with Remove, in the hint's place.
    private func markRow(_ label: String) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Text(label)
                .font(inColumn ? Tokens.Typeface.headline : Tokens.Typeface.caption)
                .foregroundStyle(inColumn ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("draw.mark.label")
            Button("Remove", action: onRemoveMark)
                .buttonStyle(RowCapsuleStyle())
                .accessibilityIdentifier("draw.mark.remove")
        }
        .lineLimit(1)
        .modifier(MarkRowFrame(inColumn: inColumn))
    }

    private var panel: some View {
        tools
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, Tokens.Space.s2 + 2)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.panel))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s3 : 0)
            .padding(.bottom, Tokens.Space.s2)
    }

    /// The Shape switch for an arrow (or a mark's help line) and the tiles, shared by the panel under the pitch and the
    /// column's card.
    private var tools: some View {
        // The mockup's 5 pt between the rows. The help line's slot is as tall as the Shape row, so the pitch keeps its
        // size when the tool changes.
        VStack(alignment: .leading, spacing: Tokens.Space.s1 + 1) {
            if tool.arrowKind != nil {
                shapeRow
            } else {
                Text(tool.help)
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Tokens.Space.s1 + 2)
                    .frame(minHeight: Self.shapeRowHeight, alignment: .leading)
                    .accessibilityIdentifier("draw.kind-help")
            }
            if dynamicTypeSize.isAccessibilitySize {
                scrollingRow
            } else {
                row(DrawTool.arrows)
                row(DrawTool.marks)
            }
        }
    }

    /// "Shape  Straight | Curved" (D-72). At the accessibility sizes it stays one row at the largest standard size, with
    /// the Large Content Viewer on each segment, so the pitch keeps its room (D-70).
    private var shapeRow: some View {
        HStack(spacing: Tokens.Space.s2 + 2) {
            Text("Shape")
                .font(.custom(Tokens.Typeface.uiName, size: 13, relativeTo: .caption).weight(.semibold))
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityIdentifier("draw.shape-label")
            CapsuleSegments(options: Self.shapes, selection: $shape, track: Tokens.Colour.surface.color, inset: 2)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Arrow shape")
        }
        .padding(.leading, Tokens.Space.s1 + 2)
        .padding(.trailing, 2)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// A segment (44 pt) on its 2 pt inset track.
    static let shapeRowHeight = Tokens.Size.touch + 4

    private static let shapes: [CapsuleSegments<ArrowShape>.Option] = [
        .init(value: .straight, title: "Straight", identifier: "draw.shape.straight"),
        .init(value: .curved, title: "Curved", identifier: "draw.shape.curved"),
    ]

    private func row(_ tools: [DrawTool]) -> some View {
        LazyVGrid(columns: columns(tools.count), spacing: Tokens.Space.s1 + 2) {
            ForEach(tools, id: \.self) { tile($0) }
        }
    }

    /// Every tool in one sideways row, each tile as wide as its name; the picked one is scrolled into view.
    private var scrollingRow: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: Tokens.Space.s1 + 2) {
                    ForEach(DrawTool.arrows + DrawTool.marks, id: \.self) { option in
                        tile(option, fitsName: true).id(option)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("draw.tools")
            .onAppear { reader.scrollTo(tool, anchor: .center) }
        }
    }

    private func tile(_ option: DrawTool, fitsName: Bool = false) -> some View {
        let on = option == tool
        return Button { tool = option } label: {
            VStack(spacing: 3) {
                ToolIcon(tool: option)
                    .frame(width: 40, height: 22)
                Text(option.title)
                    .font(Tokens.Typeface.body.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(1)
                    .minimumScaleFactor(fitsName ? 1 : 0.7)
                    .fixedSize(horizontal: fitsName, vertical: false)
            }
            .padding(.horizontal, fitsName ? Tokens.Space.s3 : 0)
            .frame(maxWidth: fitsName ? nil : .infinity, minHeight: inColumn ? Self.columnTile : Tokens.Size.kindTile)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                    .strokeBorder(on ? Tokens.Colour.text.color : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityHint(option.help)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("draw.kind.\(option.rawValue)")
    }
}

/// The mark row's frame: a strip under the pitch, or a card in the iPad column (the mockup's row card).
private struct MarkRowFrame: ViewModifier {
    let inColumn: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if inColumn {
            content
                .padding(.leading, Tokens.Space.s4 + 4)
                .padding(.trailing, Tokens.Space.s2 + 2)
                .padding(.vertical, Tokens.Space.s2 + 2)
                .frame(minHeight: 64)
                .background(Tokens.Colour.surface.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        } else {
            content
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, Tokens.Space.s2)
        }
    }
}
