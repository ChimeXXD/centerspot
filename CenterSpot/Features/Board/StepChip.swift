import SwiftUI
import TipKit

/// One chip of `StepsStrip` (UI-BRIEF §4.2, D-54): the step's number and time, lit when current; it pulses once when a
/// step is added. Tap goes to the step; press, hold and drag reorders. Made from plain values with a `nonisolated`
/// init, so the strip can build it on SwiftUI's render thread (as `StepRow`, Chime's iPad, 8 Nov).
struct StepChip: View {
    let index: Int
    let step: Step
    /// Every step's id in order, to find where a dropped chip came from.
    let ids: [String]
    let isCurrent: Bool
    let pulse: Int
    /// Whether this chip scales on `pulse`: the current one, unless Reduce Motion is on.
    let pulses: Bool
    let size: CGSize
    /// The step tip when this chip carries it (D-58).
    let tip: (any Tip)?
    let onSelect: @MainActor (Int) -> Void
    let onMove: @MainActor (_ from: Int, _ to: Int) -> Void

    nonisolated init(index: Int, step: Step, ids: [String], isCurrent: Bool, pulse: Int, pulses: Bool, size: CGSize,
                     tip: (any Tip)?, onSelect: @escaping @MainActor (Int) -> Void,
                     onMove: @escaping @MainActor (Int, Int) -> Void) {
        self.index = index
        self.step = step
        self.ids = ids
        self.isCurrent = isCurrent
        self.pulse = pulse
        self.pulses = pulses
        self.size = size
        self.tip = tip
        self.onSelect = onSelect
        self.onMove = onMove
    }

    var body: some View {
        let pulses = pulses
        Button { onSelect(index) } label: { face(on: isCurrent) }
            .buttonStyle(.plain)
            .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
                content.scaleEffect(pulses ? scale : 1)
            } keyframes: { _ in
                CubicKeyframe(1.12, duration: Tokens.Motion.step / 2)
                CubicKeyframe(1.0, duration: Tokens.Motion.step / 2)
            }
            .accessibilityLabel("Step \(index + 1), \(BoardContextRow.seconds(step.duration))")
            .accessibilityHint(isCurrent ? "Double-tap for step actions" : "Double-tap to go to this step")
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
            .accessibilityIdentifier("steps.chip.\(index + 1)")
            .centerSpotTip(tip, arrowEdge: .bottom)
            .id(step.id)
            .draggable(step.id) { face(on: true) }
            .dropDestination(for: String.self) { dropped, _ in
                guard let id = dropped.first, let from = ids.firstIndex(of: id) else { return false }
                onMove(from, index)
                return true
            }
    }

    private func face(on: Bool) -> some View {
        VStack(spacing: 1) {
            Text("\(index + 1)")
                .font(Tokens.Typeface.headline.weight(.bold))
            Text(BoardContextRow.seconds(step.duration))
                .font(Tokens.Typeface.caption.weight(.semibold))
                .foregroundStyle(on ? Tokens.Colour.accentInk.color.opacity(0.75) : Tokens.Colour.muted.color)
        }
        .foregroundStyle(on ? Tokens.Colour.accentInk.color : Tokens.Colour.text.color)
        .padding(.horizontal, Tokens.Space.s1)
        .frame(minWidth: size.width, minHeight: size.height)
        .background(on ? Tokens.Colour.accent.color : Tokens.Colour.surface2.color,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
    }
}
