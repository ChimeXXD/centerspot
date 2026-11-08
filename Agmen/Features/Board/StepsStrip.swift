import SwiftUI

/// Numbered step chips with their durations, the current one in lime, and + at the end (UI-BRIEF §4.2, D-54).
/// Tap goes to a step; tapping the current step again shows its actions; press, hold and drag reorders.
struct StepsStrip: View {
    let steps: [Step]
    let current: Int
    /// Bumped when a step is added, so the new chip pulses once (UI-BRIEF §3).
    var pulse: Int
    var onSelect: (Int) -> Void
    var onAdd: () -> Void
    var onMove: (_ from: Int, _ to: Int) -> Void
    /// The iPad portrait row uses bigger chips, closer together, and no side inset of its own (D-73).
    var chipSize = Tokens.Size.stepChip
    var spacing = Tokens.Space.s2 + 2
    var inset = Tokens.Space.s5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How wide the strip's content is, + included, so a row can give it just that (and scroll beyond).
    var contentWidth: CGFloat {
        let chips = CGFloat(steps.count + 1)
        return chips * chipSize.width + (chips - 1) * spacing + 2 * inset
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        chip(index, step)
                            .id(step.id)
                            .draggable(step.id) { chipFace(index, step, on: true) }
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first, let from = steps.firstIndex(where: { $0.id == id }) else { return false }
                                onMove(from, index)
                                return true
                            }
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

    private func chip(_ index: Int, _ step: Step) -> some View {
        let isCurrent = index == current
        return Button { onSelect(index) } label: { chipFace(index, step, on: isCurrent) }
            .buttonStyle(.plain)
            .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
                content.scaleEffect(isCurrent && !reduceMotion ? scale : 1)
            } keyframes: { _ in
                CubicKeyframe(1.12, duration: Tokens.Motion.step / 2)
                CubicKeyframe(1.0, duration: Tokens.Motion.step / 2)
            }
            .accessibilityLabel("Step \(index + 1), \(BoardContextRow.seconds(step.duration))")
            .accessibilityHint(isCurrent ? "Double-tap for step actions" : "Double-tap to go to this step")
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
            .accessibilityIdentifier("steps.chip.\(index + 1)")
            // Step 2, or step 1 when there is only one (D-78).
            .agmenTip(index == min(1, steps.count - 1) ? Onboarding.shared.current(StepTip.self) : nil, arrowEdge: .bottom)
    }

    private func chipFace(_ index: Int, _ step: Step, on: Bool) -> some View {
        VStack(spacing: 1) {
            Text("\(index + 1)")
                .font(Tokens.Typeface.headline.weight(.heavy))
            Text(BoardContextRow.seconds(step.duration))
                .font(Tokens.Typeface.caption.weight(.bold))
                .foregroundStyle(on ? Tokens.Colour.accentInk.color.opacity(0.75) : Tokens.Colour.muted.color)
        }
        .foregroundStyle(on ? Tokens.Colour.accentInk.color : Tokens.Colour.text.color)
        .padding(.horizontal, Tokens.Space.s1)
        .frame(minWidth: chipSize.width, minHeight: chipSize.height)
        .background(on ? Tokens.Colour.accent.color : Tokens.Colour.surface2.color,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
    }

    private var addChip: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(Tokens.Typeface.title.weight(.semibold))
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
