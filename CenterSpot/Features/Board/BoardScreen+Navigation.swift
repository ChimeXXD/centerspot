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
        // Its own dark track, as in the mockup, not the toolbar's glass (which washed the picked segment out).
        ToolbarItem(placement: .topBarLeading) {
            CameraSwitch(camera: $camera)
        }
        .sharedBackgroundVisibility(.hidden)
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
                    .font(Tokens.Typeface.inlineIcon)
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
            // iPad landscape hides this bar and its column nav row registers the shortcuts, so they're left off here.
            Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                .keyboardShortcut(barShortcut(.command))
                .disabled(!canUndo)
                .accessibilityIdentifier("nav.undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                .keyboardShortcut(barShortcut([.command, .shift]))
                .disabled(!canRedo)
                .accessibilityIdentifier("nav.redo")
        }
        ToolbarItem(placement: .principal) {
            titleMenu(maxWidth: max(width - Tokens.Size.navBarItems, Tokens.Size.touch * 2), sharing: layout == .compact)
        }
        // Share moved into the title's menu on the iPhone only (D-83); iPad portrait keeps it in the bar.
        if layout != .compact {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: SharedTactic(tactic: tactic), preview: SharePreview(tactic.title))
                    .accessibilityIdentifier("nav.share")
            }
        }
    }

    /// ⌘Z / ⇧⌘Z on the bar's Undo and Redo, except in iPad landscape, where the bar is hidden and the column's nav row
    /// has them (one registration each).
    private func barShortcut(_ modifiers: EventModifiers) -> KeyboardShortcut? {
        layout == .regularLandscape ? nil : KeyboardShortcut("z", modifiers: modifiers)
    }

    /// The title is our own menu (Share on the iPhone, Rename, then the mockup's "more" options: the pitch). The
    /// system's editable title sits leading at full width and folds Redo into an overflow menu when the title is long;
    /// this one truncates (D-55). On the iPhone Share lives here, so the title has room (D-83); the iPad column's nav
    /// row uses the menu too (D-73) and keeps its own Share button.
    func titleMenu(maxWidth: CGFloat, sharing: Bool = false) -> some View {
        Menu {
            if sharing {
                ShareLink(item: SharedTactic(tactic: tactic), preview: SharePreview(tactic.title)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("nav.share")
            }
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
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
            }
            .foregroundStyle(Tokens.Colour.text.color)
            .frame(maxWidth: maxWidth)
        }
        .accessibilityLabel(tactic.title)
        .accessibilityHint(sharing ? "Share, rename or change the pitch" : "Rename or change the pitch")
        .accessibilityIdentifier("nav.title")
    }

    @ViewBuilder private var pitchMenu: some View {
        Picker("Pitch", selection: Binding(get: { tactic.pitch.kind }, set: { setPitchKind($0) })) {
            Text("11-a-side").tag(Pitch.Kind.full)
            Text("7-a-side").tag(Pitch.Kind.sevenASide)
            Text("5-a-side").tag(Pitch.Kind.fiveASide)
        }
        .pickerStyle(.menu)
        Picker("Pitch style", selection: Binding(get: { tactic.pitch.style }, set: { setPitchStyle($0) })) {
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
