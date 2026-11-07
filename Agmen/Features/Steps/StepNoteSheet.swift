import SwiftUI

/// The step note editor: the coach's voice, in Kalam (UI-BRIEF §1 rule 5), up to 140 characters.
struct StepNoteSheet: View {
    let editor: DocumentEditor
    let stepIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SheetHeader(title: "Step \(stepIndex + 1) note", closeIdentifier: "note.close") { dismiss() }
            TextField("What happens in this step?", text: $text, axis: .vertical)
                .font(Tokens.Typeface.note)
                .foregroundStyle(Tokens.Colour.text.color)
                .lineLimit(2...4)
                .focused($focused)
                .padding(Tokens.Space.s3)
                .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
                .onChange(of: text) { _, new in
                    if new.count > Step.maxNoteLength { text = String(new.prefix(Step.maxNoteLength)) }
                }
                .accessibilityLabel("Note")
                .accessibilityIdentifier("note.field")
            Text("\(text.count) of \(Step.maxNoteLength)")
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityIdentifier("note.count")
            Button("Save note") {
                editor.apply("Edit note") { TacticEdits.setNote(text, step: stepIndex, in: &$0) }
                dismiss()
            }
            .buttonStyle(PrimaryCapsuleStyle())
            .accessibilityIdentifier("note.save")
        }
        .padding(.horizontal, Tokens.Space.s5)
        .padding(.top, Tokens.Space.s5)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            let steps = editor.tactic.phases.first?.steps ?? []
            text = steps.indices.contains(stepIndex) ? steps[stepIndex].note ?? "" : ""
            focused = true
        }
        .presentationDetents([.medium, .large])
        .agmenSheet()
    }
}
