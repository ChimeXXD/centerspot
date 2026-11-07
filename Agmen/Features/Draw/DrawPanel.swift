import SwiftUI

/// Under the pitch in draw mode (the mockup's "draw" and "draw--tools" screens): the handwritten hint, or the selected
/// mark's row with Remove, then a panel with the picked tool's help line and two rows of tools: the four arrows that
/// move players (D-59) and the three marks that explain (D-65). At the accessibility sizes all seven sit in one row that
/// scrolls sideways, so the pitch keeps its room (D-70). Each tile draws its line style in its colour, so arrow kinds
/// never differ by colour alone (D-15).
struct DrawPanel: View {
    @Binding var tool: DrawTool
    /// "Zone 1 · step 4" for the selected mark, or nil to show the hint.
    var selectedMark: String?
    var onRemoveMark: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func columns(_ count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s1 + 2), count: count)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selectedMark {
                markRow(selectedMark)
            } else if !dynamicTypeSize.isAccessibilitySize {
                // At the accessibility sizes the hint would push the pitch down to a thumbnail, so it's left out and the
                // pitch keeps the room (D-68). The help line below names the tool's line, not where to start.
                hint
            }
            panel
        }
    }

    private var hint: some View {
        Text(tool.hint)
            .font(Tokens.Typeface.note)
            .foregroundStyle(Tokens.Colour.muted.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s3)
            .accessibilityIdentifier("draw.hint")
            .padding(.bottom, Tokens.Space.s5)
    }

    /// The mockup's "Zone 1 · step 4" row with Remove, in the hint's place.
    private func markRow(_ label: String) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Text(label)
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("draw.mark.label")
            Button("Remove", action: onRemoveMark)
                .buttonStyle(RowCapsuleStyle())
                .accessibilityIdentifier("draw.mark.remove")
        }
        .lineLimit(1)
        .padding(.horizontal, Tokens.Space.s5)
        .padding(.vertical, Tokens.Space.s2)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(tool.help)
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Tokens.Space.s1 + 2)
                .accessibilityIdentifier("draw.kind-help")
            if dynamicTypeSize.isAccessibilitySize {
                scrollingRow
            } else {
                row(DrawTool.arrows)
                row(DrawTool.marks)
            }
        }
        .padding(.horizontal, Tokens.Space.s3)
        .padding(.vertical, Tokens.Space.s2 + 2)
        .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.panel))
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.top, dynamicTypeSize.isAccessibilitySize ? Tokens.Space.s3 : 0)
        .padding(.bottom, Tokens.Space.s2)
    }

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
                    .font(Tokens.Typeface.body.weight(.bold))
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(1)
                    .minimumScaleFactor(fitsName ? 1 : 0.7)
                    .fixedSize(horizontal: fitsName, vertical: false)
            }
            .padding(.horizontal, fitsName ? Tokens.Space.s3 : 0)
            .frame(maxWidth: fitsName ? nil : .infinity, minHeight: Tokens.Size.kindTile)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                    .strokeBorder(on ? Tokens.Colour.accent.color : .clear, lineWidth: 2)
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
