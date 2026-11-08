import SwiftUI

/// Every step as a row (D-75, iPad landscape): its number, its time and its handwritten note. Tap a row to go to the
/// step; tapping the current one again shows its actions (D-54); + adds a step; press, hold and drag reorders. The
/// current row is lit like the strip's chip. When the steps don't fit the column, the list scrolls.
struct StepsList: View {
    let steps: [Step]
    let current: Int
    /// Whether tapping the current row shows its actions (not in draw mode, where it does nothing).
    var showsStepActions = true
    /// The step tip, only while editing with no sheet open (D-58).
    var showsTip = true
    var onSelect: @MainActor (Int) -> Void
    var onAdd: () -> Void
    var onMove: @MainActor (_ from: Int, _ to: Int) -> Void

    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            header
            ViewThatFits(in: .vertical) {
                rows
                scrollingRows(rows)
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
                    .font(Tokens.Typeface.inlineIcon)
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

    /// On iPadOS 26 hardware SwiftUI builds these rows on its own render thread (`com.apple.SwiftUI.AsyncRenderer`)
    /// while it measures the list, so every closure it calls later (`ForEach`'s, `ScrollViewReader`'s) is `@Sendable`
    /// and only hands plain values on: one that reached main-actor state there failed Swift's isolation check and
    /// closed the app (Chime's iPad and Mac, 8 Nov). The tip is read here, on the main actor.
    private var rows: StepRows {
        StepRows(steps: steps, current: current, showsStepActions: showsStepActions,
                 tip: showsTip ? Onboarding.shared.current(StepTip.self) : nil,
                 tipIndex: Onboarding.stepTipIndex(stepCount: steps.count), onSelect: onSelect, onMove: onMove)
    }

    private func scrollingRows(_ rows: StepRows) -> some View {
        let ids = steps.map(\.id), current = current
        return ScrollViewReader { @Sendable proxy in
            StepRowsScroller(proxy: proxy, rows: rows, ids: ids, current: current)
        }
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
