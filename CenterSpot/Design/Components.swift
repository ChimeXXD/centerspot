import SwiftUI

// Shared Floodlight Chalk controls (UI-BRIEF §1–2). Every value comes from `Tokens`.

/// The lime capsule for a sheet's main action ("Use 4-3-3", "Choose formation").
struct PrimaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typeface.headline.weight(.bold))
            .foregroundStyle(Tokens.Colour.accentInk.color)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.capsule)
            .background(Tokens.Colour.accent.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// The quiet capsule ("Delete player"); pass a text colour for destructive actions.
struct QuietCapsuleStyle: ButtonStyle {
    var foreground: Color = Tokens.Colour.text.color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typeface.headline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: Tokens.Size.capsule)
            .background(Tokens.Colour.surface2.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A small capsule in the row under the pitch ("Edit", "Duplicate").
struct RowCapsuleStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typeface.caption.weight(.semibold))
            .foregroundStyle(Tokens.Colour.text.color)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: Tokens.Size.touch)
            .background(Tokens.Colour.surface2.color, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// The round close button at the top right of a sheet.
struct SheetCloseButton: View {
    let identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Tokens.Typeface.inlineIcon)
                .foregroundStyle(Tokens.Colour.text.color)
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .background(Tokens.Colour.surface2.color, in: Circle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier(identifier)
    }
}

/// The sheet title row: a title on the left, the close button on the right.
struct SheetHeader: View {
    let title: String
    let closeIdentifier: String
    var close: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(Tokens.Typeface.title)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            SheetCloseButton(identifier: closeIdentifier, action: close)
        }
    }
}

/// A capsule segmented control (formation sizes, the player's side).
struct CapsuleSegments<Value: Hashable & Sendable>: View {
    struct Option: Sendable {
        let value: Value
        let title: String
        let identifier: String
    }

    let options: [Option]
    @Binding var selection: Value
    /// The track behind the segments, and its inset (the Draw panel's Shape switch sits on a darker one, D-72).
    var track = Tokens.Colour.surface2.color
    var inset: CGFloat = 4
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// One row; at the accessibility sizes, a column when the row won't fit ("11-a-s…", D6-3).
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ViewThatFits(in: .horizontal) {
                segments(HStackLayout(spacing: 2), in: Capsule())
                segments(VStackLayout(spacing: 2), in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            }
        } else {
            segments(HStackLayout(spacing: 2), in: Capsule())
        }
    }

    /// `ViewThatFits` may measure these on SwiftUI's render thread (iPadOS 26 hardware), so the closure is `@Sendable`
    /// and hands plain values to `CapsuleSegment` (as `StepsList` does, Chime's iPad, 8 Nov).
    private func segments<S: Shape>(_ layout: some Layout, in shape: S) -> some View {
        let selection = $selection, current = self.selection
        return layout {
            ForEach(options, id: \.identifier) { @Sendable option in
                CapsuleSegment(option: option, on: option.value == current, selection: selection, shape: shape)
            }
        }
        .padding(inset)
        .background(track, in: shape)
    }
}

/// One segment of `CapsuleSegments`, made with a `nonisolated` init so it can be built off the main actor.
private struct CapsuleSegment<Value: Hashable & Sendable, S: Shape>: View {
    let option: CapsuleSegments<Value>.Option
    let on: Bool
    let selection: Binding<Value>
    let shape: S

    nonisolated init(option: CapsuleSegments<Value>.Option, on: Bool, selection: Binding<Value>, shape: S) {
        self.option = option
        self.on = on
        self.selection = selection
        self.shape = shape
    }

    var body: some View {
        Button { selection.wrappedValue = option.value } label: {
            Text(option.title)
                .font(Tokens.Typeface.body.weight(.semibold))
                .foregroundStyle(on ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.touch)
                .background(on ? Tokens.Colour.surface3.color : .clear, in: shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityShowsLargeContentViewer { Text(option.title) }
        .accessibilityIdentifier(option.identifier)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The small grey label above a group in a sheet ("Role · Defenders").
struct GroupLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Tokens.Typeface.caption)
            .foregroundStyle(Tokens.Colour.muted.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.s3)
    }
}

extension View {
    /// The look every CenterSpot sheet shares: surface background, 20 pt corners, dark.
    func centerSpotSheet() -> some View {
        presentationBackground(Tokens.Colour.surface.color)
            .presentationCornerRadius(Tokens.Radius.sheet)
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
    }

    /// The iPad column's row card (the mockup's row card, D-73, D-81): the context row while editing, the mark row
    /// while drawing.
    func columnCard() -> some View {
        padding(.leading, Tokens.Space.s4 + 4)
            .padding(.trailing, Tokens.Space.s3)
            .padding(.vertical, Tokens.Space.s3)
            .frame(minHeight: 64)
            .background(Tokens.Colour.surface.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
    }
}
