import SwiftUI

/// The top of the library (D-89, mockup `library-v2--phone` and `library-v2--ipad`): the last move you opened, playing
/// in the Broadcast camera with a segment per step. On a phone, under it the title, "Step 3 of 5 · 5 steps · 0:08" and
/// the step's handwritten note; the whole card opens the move. On a wide screen the steps are listed beside it, the
/// current one lit, with Open and Export video.
struct ResumeCard: View {
    let entry: TacticLibrary.Entry
    /// "Last opened", or "Example" when the example is the only move.
    let badge: String
    let wide: Bool
    /// Plays only while the library is on screen and the app is active.
    let isActive: Bool
    let onOpen: @MainActor () -> Void
    let onExport: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var loop: MoveLoop

    static let compactBoardHeight: CGFloat = 236
    /// The wide card's height, growing with Dynamic Type so its steps and buttons still fit.
    @ScaledMetric(relativeTo: .body) private var wideHeight: CGFloat = 352
    /// The steps beside the picture take at most this much, and half the card on a narrow iPad.
    static let wideInfoWidth: CGFloat = 400

    init(entry: TacticLibrary.Entry, badge: String, wide: Bool, isActive: Bool,
         onOpen: @escaping @MainActor () -> Void, onExport: @escaping @MainActor () -> Void) {
        self.entry = entry
        self.badge = badge
        self.wide = wide
        self.isActive = isActive
        self.onOpen = onOpen
        self.onExport = onExport
        _loop = State(initialValue: MoveLoop(tactic: entry.tactic))
    }

    var body: some View {
        // A one-step move has nothing to play: it rests on its step, with no clock running.
        let plays = LibraryFormat.plays(loop.duration)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive || !plays)) { context in
            let t = plays ? loop.time(at: context.date, since: start) : loop.duration
            if wide { wideCard(at: t) } else { compactCard(at: t) }
        }
        .onChange(of: entry.tactic) {
            loop = MoveLoop(tactic: entry.tactic)
            start = .now
        }
        .onChange(of: isActive) { if isActive { start = .now } }
    }

    // MARK: Phone

    private func compactCard(at t: Double) -> some View {
        let step = loop.step(at: t)
        return Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                picture(at: t).frame(height: Self.compactBoardHeight)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(entry.tactic.title)
                        .font(Tokens.Typeface.title)
                        .foregroundStyle(Tokens.Colour.text.color)
                        .lineLimit(2)
                    Text("Step \(step + 1) of \(loop.stepCount) · \(LibraryFormat.steps(entry.tactic))\(clockSuffix)")
                        .font(Tokens.Typeface.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Colour.muted.color)
                        .monospacedDigit()
                    if let note = note(step) {
                        Text(note)
                            .font(Tokens.Typeface.note)
                            .foregroundStyle(Tokens.Colour.text.color)
                            .lineLimit(2, reservesSpace: true)
                            .padding(.top, Tokens.Space.s1)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: Tokens.Space.s3, leading: Tokens.Space.s4, bottom: Tokens.Space.s4, trailing: Tokens.Space.s4))
            }
            .background(Tokens.Colour.surface.color)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sheet))
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.sheet))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge): \(entry.tactic.title)")
        .accessibilityValue(spokenSummary)
        .accessibilityHint("Opens the move")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("library.resume")
    }

    // MARK: Wide

    private func wideCard(at t: Double) -> some View {
        let step = loop.step(at: t), steps = entry.tactic.phases.first?.steps ?? []
        return HStack(spacing: 0) {
            Button(action: onOpen) { picture(at: t) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(badge): \(entry.tactic.title)")
                .accessibilityValue(spokenSummary)
                .accessibilityHint("Opens the move")
                .accessibilityIdentifier("library.resume")
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text("Pick up where you left off")
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.muted.color)
                Text(entry.tactic.title)
                    .font(Tokens.Typeface.title)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Text("\(LibraryFormat.steps(entry.tactic))\(clockSuffix) · Edited \(LibraryFormat.editedInSentence(entry.modified))")
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .monospacedDigit()
                    .padding(.bottom, Tokens.Space.s2)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { @Sendable index, item in
                        ResumeStepRow(index: index, duration: item.duration, note: item.note, isCurrent: index == step)
                    }
                }
                Spacer(minLength: Tokens.Space.s3)
                HStack(spacing: Tokens.Space.s2) {
                    Button("Open", action: onOpen)
                        .buttonStyle(QuietCapsuleStyle())
                        .accessibilityIdentifier("library.resume.open")
                    Button(action: onExport) { Label("Export video", systemImage: "square.and.arrow.up") }
                        .buttonStyle(QuietCapsuleStyle())
                        .accessibilityIdentifier("library.resume.export")
                }
            }
            .padding(EdgeInsets(top: Tokens.Space.s5, leading: Tokens.Space.s5, bottom: Tokens.Space.s5, trailing: Tokens.Space.s5))
            .frame(maxWidth: Self.wideInfoWidth, alignment: .topLeading)
        }
        .frame(height: wideHeight)
        .background(Tokens.Colour.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sheet))
    }

    // MARK: Parts

    /// The move playing, with its badge and the step segments.
    private func picture(at t: Double) -> some View {
        MoveLoopBoard(loop: loop, t: t, reduceMotion: reduceMotion)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colour.bcPitchA.color)
            .overlay(alignment: .topLeading) {
                Text(badge)
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.text.color)
                    .padding(.horizontal, Tokens.Space.s2)
                    .padding(.vertical, Tokens.Space.s1)
                    .background(Tokens.Colour.bg.color.opacity(0.72), in: Capsule())
                    .padding(Tokens.Space.s3)
                    .accessibilityHidden(true)
            }
            .clipped()
            // Under the picture, never over the near players.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MoveLoopScrubber(loop: loop, t: t)
                    .padding(.horizontal, Tokens.Space.s3)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.Colour.bcPitchA.color)
            }
    }

    private func note(_ step: Int) -> String? {
        guard let steps = entry.tactic.phases.first?.steps, steps.indices.contains(step),
              let note = steps[step].note, !note.isEmpty else { return nil }
        return note
    }

    /// " · 0:08", or nothing for a one-step move, which has no length (D-89).
    private var clockSuffix: String {
        LibraryFormat.plays(loop.duration) ? " · \(LibraryFormat.clock(loop.duration))" : ""
    }

    /// "5 steps, 8 seconds"; a one-step move only "1 step".
    private var spokenSummary: String {
        let steps = LibraryFormat.steps(entry.tactic)
        return LibraryFormat.plays(loop.duration) ? "\(steps), \(LibraryFormat.spokenLength(loop.duration))" : steps
    }
}

/// One step beside the wide card's picture: number, duration and handwritten note, lit while it plays.
private struct ResumeStepRow: View {
    let index: Int
    let duration: Double
    let note: String?
    let isCurrent: Bool

    nonisolated init(index: Int, duration: Double, note: String?, isCurrent: Bool) {
        self.index = index
        self.duration = duration
        self.note = note
        self.isCurrent = isCurrent
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
            Text("\(index + 1)")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .frame(minWidth: 20, alignment: .leading)
            Text(BoardContextRow.seconds(duration))
                .font(Tokens.Typeface.caption.weight(.semibold))
                .foregroundStyle(Tokens.Colour.muted.color)
                .frame(minWidth: 36, alignment: .leading)
            Text(note.flatMap { $0.isEmpty ? nil : $0 } ?? "No note")
                .font(Tokens.Typeface.note)
                .foregroundStyle(isCurrent ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Tokens.Space.s2)
        .padding(.vertical, 2)
        .background(isCurrent ? Tokens.Colour.surface2.color : .clear, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library.resume.step.\(index + 1)")
    }
}
