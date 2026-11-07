import SwiftUI

/// A short message over the bottom of the pitch, with Undo when the message is about an edit ("Deleted step 3").
struct BoardToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    /// The tactic right after the edit the toast offers to undo; nil when it offers no Undo.
    var undoesTo: Tactic?
    /// The step to show again after Undo (a deleted step comes back on screen).
    var returnsTo: Int?

    var offersUndo: Bool { undoesTo != nil }

    /// How long a toast stays up.
    static let lifetime: Duration = .seconds(4)
}

struct BoardToastView: View {
    let toast: BoardToast
    var onUndo: () -> Void

    var body: some View {
        HStack {
            Text(toast.message)
                .font(Tokens.Typeface.body)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityIdentifier("toast.message")
            Spacer(minLength: Tokens.Space.s2)
            if toast.offersUndo {
                Button("Undo", action: onUndo)
                    .font(Tokens.Typeface.body.weight(.heavy))
                    .foregroundStyle(Tokens.Colour.accent.color)
                    .padding(.horizontal, Tokens.Space.s4)
                    .frame(minHeight: Tokens.Size.touch)
                    .accessibilityIdentifier("toast.undo")
            }
        }
        .padding(.leading, Tokens.Space.s4 + 2)
        .padding(.trailing, Tokens.Space.s1 + 2)
        .frame(minHeight: Tokens.Size.toast)
        .background(Tokens.Colour.surface3.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        .shadow(color: Tokens.Colour.bg.color.opacity(0.4), radius: 12, y: 8)
        .accessibilityElement(children: .contain)
    }
}
