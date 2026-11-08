import SwiftUI
import TipKit

/// One row of the iPad's steps list (D-75): number, time and handwritten note, lit when current. Tap goes to the step;
/// press, hold and drag reorders. Made from plain values with a `nonisolated` init, so `StepRows` can build it on
/// SwiftUI's render thread (iPadOS 26 hardware does); its body still runs on the main actor.
struct StepRow: View {
    let index: Int
    let step: Step
    /// Every step's id in order, to find where a dropped row came from.
    let ids: [String]
    let isCurrent: Bool
    let showsStepActions: Bool
    /// The step tip when this row carries it (D-58).
    let tip: (any Tip)?
    let onSelect: @MainActor (Int) -> Void
    let onMove: @MainActor (_ from: Int, _ to: Int) -> Void

    nonisolated init(index: Int, step: Step, ids: [String], isCurrent: Bool, showsStepActions: Bool, tip: (any Tip)?,
                     onSelect: @escaping @MainActor (Int) -> Void, onMove: @escaping @MainActor (Int, Int) -> Void) {
        self.index = index
        self.step = step
        self.ids = ids
        self.isCurrent = isCurrent
        self.showsStepActions = showsStepActions
        self.tip = tip
        self.onSelect = onSelect
        self.onMove = onMove
    }

    var body: some View {
        Button { onSelect(index) } label: { face(on: isCurrent) }
            .buttonStyle(.plain)
            .draggable(step.id) { face(on: true).frame(width: 320) }
            .dropDestination(for: String.self) { dropped, _ in
                guard let id = dropped.first, let from = ids.firstIndex(of: id) else { return false }
                onMove(from, index)
                return true
            }
            .accessibilityLabel(StepsList.label(index: index, count: ids.count, step: step))
            .accessibilityHint(hint)
            .accessibilityAddTraits(isCurrent ? .isSelected : [])
            .accessibilityIdentifier("steps.row.\(index + 1)")
            .agmenTip(tip, arrowEdge: .trailing)
            .id(step.id)
    }

    private var hint: String {
        guard isCurrent else { return "Double-tap to go to this step" }
        return showsStepActions ? "Double-tap for step actions" : ""
    }

    private func face(on: Bool) -> some View {
        let ink = on ? Tokens.Colour.accentInk.color : Tokens.Colour.text.color
        let quiet = on ? Tokens.Colour.accentInk.color.opacity(0.75) : Tokens.Colour.muted.color
        return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
            Text("\(index + 1)")
                .font(Tokens.Typeface.title)
                .foregroundStyle(ink)
                .frame(minWidth: 28, alignment: .leading)
            Text(BoardContextRow.seconds(step.duration))
                .font(Tokens.Typeface.caption.weight(.semibold))
                .foregroundStyle(quiet)
                .frame(minWidth: 40, alignment: .leading)
            Text(noteText)
                .font(Tokens.Typeface.note)
                .foregroundStyle(step.note?.isEmpty == false ? ink : quiet)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, Tokens.Space.s2)
        .frame(minHeight: Tokens.Size.stepChip.height)
        .background(on ? Tokens.Colour.accent.color : Tokens.Colour.surface2.color,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.item))
    }

    private var noteText: String {
        if let note = step.note, !note.isEmpty { return note }
        return "No note"
    }
}

/// Every `StepRow` in a column, from plain values (`StepsList` reads the tip on the main actor), so the list can hand
/// the same rows to its scrolling variant from a `@Sendable` closure.
struct StepRows: View {
    let steps: [Step]
    let current: Int
    let showsStepActions: Bool
    let tip: (any Tip)?
    let tipIndex: Int
    let onSelect: @MainActor (Int) -> Void
    let onMove: @MainActor (_ from: Int, _ to: Int) -> Void

    nonisolated init(steps: [Step], current: Int, showsStepActions: Bool, tip: (any Tip)?, tipIndex: Int,
                     onSelect: @escaping @MainActor (Int) -> Void, onMove: @escaping @MainActor (Int, Int) -> Void) {
        self.steps = steps
        self.current = current
        self.showsStepActions = showsStepActions
        self.tip = tip
        self.tipIndex = tipIndex
        self.onSelect = onSelect
        self.onMove = onMove
    }

    var body: some View {
        let ids = steps.map(\.id), current = current, showsStepActions = showsStepActions
        let tip = tip, tipIndex = tipIndex, onSelect = onSelect, onMove = onMove
        VStack(spacing: Tokens.Space.s2) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { @Sendable index, step in
                StepRow(index: index, step: step, ids: ids, isCurrent: index == current, showsStepActions: showsStepActions,
                        tip: index == tipIndex ? tip : nil, onSelect: onSelect, onMove: onMove)
            }
        }
    }
}

/// The steps list's scrolling variant: the rows in a scroll view that keeps the current step in sight. Built by a
/// `@Sendable` `ScrollViewReader` closure, so its init is `nonisolated`.
struct StepRowsScroller: View {
    /// Not `Sendable`, so the nonisolated init stores it unchecked; it is only used in `onAppear` and `onChange`, which
    /// run on the main actor.
    nonisolated(unsafe) let proxy: ScrollViewProxy
    let rows: StepRows
    /// Every step's id in order, to scroll to one.
    let ids: [String]
    let current: Int

    nonisolated init(proxy: ScrollViewProxy, rows: StepRows, ids: [String], current: Int) {
        self.proxy = proxy
        self.rows = rows
        self.ids = ids
        self.current = current
    }

    var body: some View {
        ScrollView(.vertical) { rows }
            .scrollIndicators(.automatic)
            .onAppear { scroll(to: current, animated: false) }
            .onChange(of: current) { _, new in scroll(to: new, animated: true) }
    }

    private func scroll(to index: Int, animated: Bool) {
        guard ids.indices.contains(index) else { return }
        withAnimation(animated ? Tokens.Motion.ease(Tokens.Motion.step) : nil) { proxy.scrollTo(ids[index]) }
    }
}
