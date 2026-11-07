import SwiftUI

// Shared Floodlight Chalk controls (UI-BRIEF §1–2). Every value comes from `Tokens`.

/// The lime capsule for a sheet's main action ("Use 4-3-3", "Choose formation").
struct PrimaryCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Typeface.headline.weight(.heavy))
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
            .font(Tokens.Typeface.headline.weight(.heavy))
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
            .font(Tokens.Typeface.caption.weight(.bold))
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
                .font(Tokens.Typeface.headline)
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
struct CapsuleSegments<Value: Hashable>: View {
    struct Option {
        let value: Value
        let title: String
        let identifier: String
    }

    let options: [Option]
    @Binding var selection: Value
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

    private func segments(_ layout: some Layout, in shape: some Shape) -> some View {
        layout {
            ForEach(options, id: \.identifier) { option in
                let on = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title)
                        .font(Tokens.Typeface.body.weight(.bold))
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
        .padding(3)
        .background(Tokens.Colour.surface2.color, in: shape)
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
    /// The look every Agmen sheet shares: surface background, 20 pt corners, dark.
    func agmenSheet() -> some View {
        presentationBackground(Tokens.Colour.surface.color)
            .presentationCornerRadius(Tokens.Radius.sheet)
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
    }
}
