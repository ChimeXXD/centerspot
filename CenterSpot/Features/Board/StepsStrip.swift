import SwiftUI

/// Numbered step chips with their durations, the current one in lime, and + at the end (UI-BRIEF §4.2, D-54).
/// Tap goes to a step; tapping the current step again shows its actions; press, hold and drag reorders.
struct StepsStrip: View {
    let steps: [Step]
    let current: Int
    /// Bumped when a step is added, so the new chip pulses once (UI-BRIEF §3).
    var pulse: Int
    var onSelect: @MainActor (Int) -> Void
    var onAdd: () -> Void
    var onMove: @MainActor (_ from: Int, _ to: Int) -> Void
    /// The iPad portrait row uses bigger chips and no side inset of its own (D-73); both rows space chips 8 pt (D-81).
    var chipSize = Tokens.Size.stepChip
    var spacing = Tokens.Space.s2
    var inset = Tokens.Space.s5
    /// The step tip, only while editing with no sheet open (D-58).
    var showsTip = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How wide the strip's content is, + included, so a row can give it just that (and scroll beyond).
    var contentWidth: CGFloat {
        let chips = CGFloat(steps.count + 1)
        return chips * chipSize.width + (chips - 1) * spacing + 2 * inset
    }

    /// Like `StepsList`'s rows (Chime's iPad, 8 Nov): the `ForEach` closure is `@Sendable` and hands plain values to
    /// `StepChip`, so SwiftUI's render thread can build the chips; the tip and Reduce Motion are read here.
    var body: some View {
        let tip = showsTip ? Onboarding.shared.current(StepTip.self) : nil
        let tipIndex = Onboarding.stepTipIndex(stepCount: steps.count)
        let ids = steps.map(\.id), current = current, pulse = pulse, chipSize = chipSize, reduceMotion = reduceMotion
        let onSelect = onSelect, onMove = onMove
        return ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { @Sendable index, step in
                        StepChip(index: index, step: step, ids: ids, isCurrent: index == current, pulse: pulse,
                                 pulses: index == current && !reduceMotion, size: chipSize,
                                 tip: index == tipIndex ? tip : nil, onSelect: onSelect, onMove: onMove)
                    }
                    addChip
                }
                .padding(.horizontal, inset)
            }
            .scrollIndicators(.hidden)
            .onChange(of: current) { _, new in
                guard steps.indices.contains(new) else { return }
                withAnimation(Tokens.Motion.ease(Tokens.Motion.step)) { proxy.scrollTo(steps[new].id) }
            }
        }
    }

    private var addChip: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(Tokens.Typeface.inlineIcon)
                .foregroundStyle(Tokens.Colour.text.color)
                .frame(minWidth: chipSize.width, minHeight: chipSize.height)
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.item)
                        .strokeBorder(Tokens.Colour.muted.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.item))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a step")
        .accessibilityIdentifier("steps.add")
    }
}
