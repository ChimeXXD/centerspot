import Combine
import SwiftUI

/// The board's nav bar for each mode, and the Undo and Redo state behind it.
extension BoardScreen {
    @ToolbarContentBuilder var navigationItems: some ToolbarContent {
        switch mode {
        case .editing: editingItems
        case .playing: playingItems
        case .drawing: drawingItems
        }
    }

    /// Playback leaves the edit history alone; Done returns to the step it stopped on.
    @ToolbarContentBuilder private var playingItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(tactic.title)
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(1)
                .accessibilityIdentifier("nav.title")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done", action: stopPlayback)
                .font(Tokens.Typeface.headline)
                .accessibilityHint("Back to editing this step")
                .accessibilityIdentifier("playback.done")
        }
    }

    /// The mockup's draw screen: close on the left, "Draw", the lime Done on the right.
    @ToolbarContentBuilder private var drawingItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel drawing", systemImage: "xmark", action: cancelDrawing)
                .accessibilityIdentifier("draw.cancel")
        }
        ToolbarItem(placement: .principal) {
            Text("Draw")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("draw.title")
        }
        ToolbarItem(placement: .topBarTrailing) {
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

    @ToolbarContentBuilder private var editingItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            // The board's UndoManager isn't the window's (D-56), so a hardware keyboard needs these shortcuts.
            Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!canUndo)
                .accessibilityIdentifier("nav.undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!canRedo)
                .accessibilityIdentifier("nav.redo")
        }
        // The title is our own menu (Rename, then the mockup's "more" options: the pitch). The system's editable
        // title sits leading at full width and folds Redo and Share into an overflow menu when the title is long;
        // this one truncates, so Share stays visible (D-55).
        ToolbarItem(placement: .principal) {
            Menu {
                Button("Rename", systemImage: "pencil") {
                    newTitle = tactic.title
                    renaming = true
                }
                pitchMenu
            } label: {
                HStack(spacing: Tokens.Space.s1) {
                    Text(tactic.title)
                        .font(Tokens.Typeface.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.down")
                        .font(Tokens.Typeface.caption.weight(.heavy))
                        .foregroundStyle(Tokens.Colour.muted.color)
                }
                .foregroundStyle(Tokens.Colour.text.color)
                .frame(maxWidth: max(width - Tokens.Size.navBarItems, Tokens.Size.touch * 2))
            }
            .accessibilityLabel(tactic.title)
            .accessibilityHint("Rename or change the pitch")
            .accessibilityIdentifier("nav.title")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Share", systemImage: "square.and.arrow.up") { show("Sharing comes on Day 6") }
                .accessibilityIdentifier("nav.share")
        }
    }

    @ViewBuilder private var pitchMenu: some View {
        Picker("Pitch", selection: Binding(get: { tactic.pitch.kind }, set: setPitchKind)) {
            Text("11-a-side").tag(Pitch.Kind.full)
            Text("7-a-side").tag(Pitch.Kind.sevenASide)
            Text("5-a-side").tag(Pitch.Kind.fiveASide)
        }
        .pickerStyle(.menu)
        Picker("Pitch style", selection: Binding(get: { tactic.pitch.style }, set: setPitchStyle)) {
            Text("Stripes").tag(Pitch.Style.stripes)
            Text("Plain").tag(Pitch.Style.plain)
        }
        .pickerStyle(.menu)
    }

    // MARK: Undo state

    var undoChanges: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.MergeMany(
            center.publisher(for: .NSUndoManagerDidCloseUndoGroup),
            center.publisher(for: .NSUndoManagerDidUndoChange),
            center.publisher(for: .NSUndoManagerDidRedoChange)
        )
        .eraseToAnyPublisher()
    }

    func refreshUndo() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }
}
