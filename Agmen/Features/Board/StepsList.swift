import SwiftUI

/// Every step as a row (D-75, iPad landscape): its number, its time and its handwritten note. Tap a row to go to the
/// step; tapping the current one again shows its actions (D-54); + adds a step; press, hold and drag reorders. The
/// current row is lit like the strip's chip. When the steps don't fit the column, the list scrolls.
struct StepsList: View {
    let steps: [Step]
    let current: Int
    /// Whether tapping the current row shows its actions (not in draw mode, where it does nothing).
    var showsStepActions = true
    var onSelect: (Int) -> Void
    var onAdd: () -> Void
    var onMove: (_ from: Int, _ to: Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            header
            ViewThatFits(in: .vertical) {
                rows
                scrollingRows
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Steps")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.muted.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("steps.title")
            Spacer(minLength: Tokens.Space.s2)
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(Tokens.Typeface.headline.weight(.heavy))
                    .foregroundStyle(Tokens.Colour.text.color)
                    .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                    .overlay {
                        Circle().strokeBorder(Tokens.Colour.muted.color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a step")
            .accessibilityIdentifier("steps.add")
        }
    }

    private var rows: some View {
        VStack(spacing: Tokens.Space.s2) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                row(index, step).id(step.id)
            }
        }
    }

    private var scrollingRows: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) { rows }
                .scrollIndicators(.automatic)
                .onAppear { scroll(proxy, to: current, animated: false) }
                .onChange(of: current) { _, new in scroll(proxy, to: new, animated: true) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to index: Int, animated: Bool) {
        guard steps.indices.contains(index) else { return }
        withAnimation(animated ? Tokens.Motion.ease(Tokens.Motion.step) : nil) { proxy.scrollTo(steps[index].id) }
    }

    private func row(_ index: Int, _ step: Step) -> some View {
        Button { onSelect(index) } label: { rowFace(index, step, on: index == current) }
            .buttonStyle(.plain)
            .draggable(step.id) { rowFace(index, step, on: true).frame(width: 320) }
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first, let from = steps.firstIndex(where: { $0.id == id }) else { return false }
                onMove(from, index)
                return true
            }
            .accessibilityLabel(Self.label(index: index, count: steps.count, step: step))
            .accessibilityHint(hint(isCurrent: index == current))
            .accessibilityAddTraits(index == current ? .isSelected : [])
            .accessibilityIdentifier("steps.row.\(index + 1)")
    }

    private func hint(isCurrent: Bool) -> String {
        guard isCurrent else { return "Double-tap to go to this step" }
        return showsStepActions ? "Double-tap for step actions" : ""
    }

    private func rowFace(_ index: Int, _ step: Step, on: Bool) -> some View {
        let ink = on ? Tokens.Colour.accentInk.color : Tokens.Colour.text.color
        let quiet = on ? Tokens.Colour.accentInk.color.opacity(0.75) : Tokens.Colour.muted.color
        return HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
            Text("\(index + 1)")
                .font(Tokens.Typeface.title)
                .foregroundStyle(ink)
                .frame(minWidth: 28, alignment: .leading)
            Text(BoardContextRow.seconds(step.duration))
                .font(Tokens.Typeface.caption.weight(.bold))
                .foregroundStyle(quiet)
                .frame(minWidth: 40, alignment: .leading)
            Text(noteText(step))
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

    private func noteText(_ step: Step) -> String {
        if let note = step.note, !note.isEmpty { return note }
        return "No note"
    }

    /// "Step 2 of 5, 1.4 seconds, 11 drives inside; 3 starts the overlap".
    static func label(index: Int, count: Int, step: Step) -> String {
        let value = step.duration.formatted(.number.precision(.fractionLength(0...1)))
        let seconds = step.duration == 1 ? "1 second" : "\(value) seconds"
        let head = "Step \(index + 1) of \(count), \(seconds)"
        guard let note = step.note, !note.isEmpty else { return head }
        return "\(head), \(note)"
    }
}
