import SwiftUI

/// iPad landscape (D-73): the nav bar moves into the top of the right column so the pitch can run from under the
/// status bar to the toolbar. Same items, labels and identifiers as the system nav bar in each mode.
extension BoardScreen {
    var columnNavRow: some View {
        ZStack {
            columnNavTitle
                .padding(.horizontal, Tokens.Size.touch * 3)
            HStack(spacing: Tokens.Space.s2) {
                columnNavLeading
                Spacer(minLength: 0)
                columnNavTrailing
            }
        }
        .frame(height: 50)
        .padding(.horizontal, -Tokens.Space.s3)
    }

    @ViewBuilder private var columnNavTitle: some View {
        switch mode {
        case .editing:
            titleMenu(maxWidth: .infinity)
        case .playing:
            Text(tactic.title)
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(1)
                .accessibilityIdentifier("nav.title")
        case .drawing:
            Text("Draw")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("draw.title")
        }
    }

    @ViewBuilder private var columnNavLeading: some View {
        switch mode {
        case .editing:
            navIcon("Back", symbol: "chevron.backward", identifier: "nav.back") { dismiss() }
        case .playing:
            CameraSwitch(camera: $camera)
        case .drawing:
            navIcon("Cancel drawing", symbol: "xmark", identifier: "draw.cancel", action: cancelDrawing)
        }
    }

    @ViewBuilder private var columnNavTrailing: some View {
        switch mode {
        case .editing:
            HStack(spacing: 0) {
                navIcon("Undo", symbol: "arrow.uturn.backward", identifier: "nav.undo") { undoManager?.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!canUndo)
                    .opacity(canUndo ? 1 : 0.4)
                navIcon("Redo", symbol: "arrow.uturn.forward", identifier: "nav.redo") { undoManager?.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!canRedo)
                    .opacity(canRedo ? 1 : 0.4)
            }
            .padding(.horizontal, Tokens.Space.s1)
            .background(Tokens.Colour.surface2.color, in: Capsule())
            navIcon("Share", symbol: "square.and.arrow.up", identifier: "nav.share") { show("Sharing comes on Day 6") }
        case .playing:
            Button("Done", action: stopPlayback)
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.accent.color)
                .frame(minWidth: Tokens.Size.touch, minHeight: Tokens.Size.touch)
                .accessibilityHint("Back to editing this step")
                .accessibilityIdentifier("playback.done")
        case .drawing:
            Button(action: finishDrawing) {
                Image(systemName: "checkmark")
                    .font(Tokens.Typeface.headline.weight(.heavy))
                    .foregroundStyle(Tokens.Colour.accentInk.color)
                    .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                    .background(Tokens.Colour.accent.color, in: Circle())
            }
            .accessibilityLabel("Done")
            .accessibilityIdentifier("draw.done")
        }
    }

    private func navIcon(_ title: String, symbol: String, identifier: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Tokens.Typeface.title.weight(.semibold))
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Tokens.Colour.text.color)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}
