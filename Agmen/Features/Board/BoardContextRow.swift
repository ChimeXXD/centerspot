import SwiftUI

/// The row under the pitch (UI-BRIEF §1 rule 1): the formation and step by default, the actions for a selected
/// token, or the actions for the current step once its chip is tapped again (D-54). Nothing floats over the pitch.
struct BoardContextRow: View {
    enum Mode {
        case summary(tag: String, step: String)
        case token(label: String, isPlayer: Bool)
        case step(number: Int, duration: Double, canDelete: Bool)
    }

    let mode: Mode
    var onEdit: () -> Void = {}
    var onDrawRun: () -> Void = {}
    var onRemove: () -> Void = {}
    var onDuration: (Double) -> Void = { _ in }
    var onDuplicate: () -> Void = {}
    var onNote: () -> Void = {}
    var onDeleteStep: () -> Void = {}

    /// Durations offered for a step (SPEC §2: 0.3…5 s).
    static let durations: [Double] = [0.3, 0.5, 0.8, 1, 1.2, 1.4, 1.6, 2, 2.5, 3, 4, 5]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At the accessibility sizes the row scrolls sideways at full size instead of truncating every label (D6-3).
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                row.fixedSize()
                    .frame(minHeight: Tokens.Size.touch)
            }
            .scrollIndicators(.hidden)
        } else {
            row.frame(height: Tokens.Size.touch)
        }
    }

    private var row: some View {
        HStack(spacing: Tokens.Space.s2) {
            switch mode {
            case let .summary(tag, step):
                Text(tag)
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .padding(.horizontal, Tokens.Space.s3)
                    .padding(.vertical, Tokens.Space.s1)
                    .background(Tokens.Colour.surface2.color, in: Capsule())
                    .accessibilityIdentifier("board.formation-tag")
                Spacer(minLength: Tokens.Space.s2)
                Text(step)
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .accessibilityIdentifier("board.step-label")
            case let .token(label, isPlayer):
                rowLabel(label, identifier: "selection.label")
                if isPlayer {
                    button("Edit", "selection.edit", onEdit)
                    button("Draw run", "selection.run", onDrawRun)
                }
                button("Remove", "selection.delete", onRemove)
            case let .step(number, duration, canDelete):
                rowLabel("Step \(number)", identifier: "steps.hint")
                durationMenu(duration)
                button("Duplicate", "step.duplicate", onDuplicate)
                button("Note", "step.note", onNote)
                button("Delete", "step.delete", onDeleteStep).disabled(!canDelete)
            }
        }
        .lineLimit(1)
    }

    private func rowLabel(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(Tokens.Typeface.caption)
            .foregroundStyle(Tokens.Colour.muted.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(identifier)
    }

    private func button(_ title: String, _ identifier: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(RowCapsuleStyle())
            .accessibilityIdentifier(identifier)
    }

    private func durationMenu(_ duration: Double) -> some View {
        Menu {
            Picker("Duration", selection: Binding(get: { duration }, set: { onDuration($0) })) {
                ForEach(Self.durations, id: \.self) { Text(Self.seconds($0)).tag($0) }
            }
        } label: {
            Text(Self.seconds(duration))
        }
        .buttonStyle(RowCapsuleStyle())
        .accessibilityLabel("Duration, \(Self.seconds(duration))")
        .accessibilityIdentifier("step.duration")
    }

    /// "1.2 s", "1 s".
    static func seconds(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) s"
    }
}
