import SwiftUI

/// The bottom toolbar (D-55): Formation · + Add · Play (centred lime disc) · Draw · Export.
struct BoardToolbar: View {
    var hasBall: Bool
    var onFormation: () -> Void
    var onAdd: (TacticEdits.NewToken) -> Void
    var onPlay: () -> Void
    var onDraw: () -> Void
    var onExport: () -> Void
    /// iPad landscape keeps the toolbar in draw mode (D-73): Draw lit, the others disabled.
    var drawing = false
    /// On iPad the five items gather in the middle (the mockup's 72 pt gaps) instead of spreading across the screen.
    var itemsWidth = CGFloat.infinity

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tool("Formation", symbol: "circle.grid.2x1", identifier: "toolbar.formation", action: onFormation)
                .modifier(Off(drawing))
            addMenu.modifier(Off(drawing))
            playButton.modifier(Off(drawing))
                .agmenTip(drawing ? nil : Onboarding.shared.current(PlayTip.self), arrowEdge: .bottom)
            tool("Draw", symbol: "pencil", identifier: "toolbar.draw", lit: drawing, action: onDraw)
                .accessibilityAddTraits(drawing ? .isSelected : [])
                .agmenTip(drawing ? nil : Onboarding.shared.current(DrawTip.self), arrowEdge: .bottom)
            tool("Export", symbol: "film", identifier: "toolbar.export", action: onExport)
                .modifier(Off(drawing))
                .agmenTip(drawing ? nil : Onboarding.shared.current(ExportTip.self), arrowEdge: .bottom)
        }
        .frame(maxWidth: itemsWidth)
        .padding(.horizontal, Tokens.Space.s1 + 2)
        .padding(.top, Tokens.Space.s2)
        .frame(height: Tokens.Size.toolbarHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Tokens.Colour.surface.color.ignoresSafeArea(edges: .bottom))
        // Like a system tab bar, the labels stop growing at the default size; at the accessibility sizes a long
        // press shows each one in the Large Content Viewer (D6-3, AX5 review: "Fo…", "Dr…", "Ex…").
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func label(_ title: String, symbol: String, lit: Bool = false) -> some View {
        VStack(spacing: Tokens.Space.s1) {
            Image(systemName: symbol)
                .font(Tokens.Typeface.title.weight(.regular))
                .frame(height: 28)
            Text(title)
                .font(Tokens.Typeface.caption)
        }
        .foregroundStyle(lit ? Tokens.Colour.accent.color : Tokens.Colour.muted.color)
        .frame(maxWidth: .infinity, minHeight: 60)
        .contentShape(Rectangle())
    }

    private func tool(_ title: String, symbol: String, identifier: String, lit: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) { label(title, symbol: symbol, lit: lit) }
            .buttonStyle(.plain)
            .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
            .accessibilityLabel(title)
            .accessibilityIdentifier(identifier)
    }

    private var addMenu: some View {
        Menu {
            Button("Our player", systemImage: "circle.fill") { onAdd(.ourPlayer) }
            Button("Their player", systemImage: "circle") { onAdd(.theirPlayer) }
            Button("Ball", systemImage: "soccerball") { onAdd(.ball) }.disabled(hasBall)
            Button("Cone", systemImage: "cone") { onAdd(.cone) }
        } label: {
            label("Add", symbol: "plus.circle")
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer { Label("Add", systemImage: "plus.circle") }
        .accessibilityLabel("Add")
        .accessibilityHint("Adds a player, the ball or a cone on the centre spot")
        .accessibilityIdentifier("toolbar.add")
    }

    private var playButton: some View {
        Button(action: onPlay) {
            VStack(spacing: Tokens.Space.s1) {
                Image(systemName: "play.fill")
                    .font(Tokens.Typeface.title)
                    .foregroundStyle(Tokens.Colour.accentInk.color)
                    .frame(width: Tokens.Size.playDisc, height: Tokens.Size.playDisc)
                    .background(Tokens.Colour.accent.color, in: Circle())
                    .padding(.top, -Tokens.Space.s2 + 2)
                Text("Play")
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.text.color)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer { Label("Play", systemImage: "play.fill") }
        .accessibilityLabel("Play")
        .accessibilityIdentifier("toolbar.play")
    }
}

/// A toolbar item that can't be used right now: disabled and faded, as in the mockup's draw frame.
private struct Off: ViewModifier {
    let isOff: Bool
    init(_ isOff: Bool) { self.isOff = isOff }

    func body(content: Content) -> some View {
        content.disabled(isOff).opacity(isOff ? 0.4 : 1)
    }
}
