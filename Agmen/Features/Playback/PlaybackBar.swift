import SwiftUI

/// What replaces the steps strip and toolbar while the move plays (UI-BRIEF §4.5, the mockup's "playback" screen): one
/// segment per step that fills as it plays, the step's handwritten note, the time, then Loop · Previous · Play/Pause ·
/// Next · speed. Every value comes from `PlaybackTrack` at the `t` it is given.
struct PlaybackBar: View {
    let phase: Phase
    let t: Double
    let isPlaying: Bool
    let loops: Bool
    let speed: Double
    var onToggle: () -> Void
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onLoop: () -> Void
    var onSpeed: (Double) -> Void
    /// A place on the scrubber (0…1), and whether the finger has lifted.
    var onScrub: (Double, Bool) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stepIndex: Int {
        let starts = PlaybackTrack.starts(of: phase)
        return starts.lastIndex { $0 <= t + 1e-9 } ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            scrubber
                .padding(.horizontal, Tokens.Space.s5)
            note
                .padding(.horizontal, Tokens.Space.s5)
            Text(Self.time(t, of: Timeline.duration(of: phase)))
                .font(Tokens.Typeface.caption.monospacedDigit())
                .foregroundStyle(Tokens.Colour.muted.color)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, Tokens.Space.s2)
                .accessibilityIdentifier("playback.time")
            controls
        }
    }

    // MARK: Scrubber

    private var scrubber: some View {
        GeometryReader { proxy in
            HStack(spacing: Tokens.Size.scrubberGap) {
                ForEach(phase.steps.indices, id: \.self) { index in
                    let fill = PlaybackTrack.fill(segment: index, at: t, in: phase)
                    Capsule()
                        .fill(Tokens.Colour.surface2.color)
                        .overlay(alignment: .leading) {
                            GeometryReader { bar in
                                Capsule()
                                    .fill(Tokens.Colour.accent.color)
                                    .frame(width: bar.size.width * fill)
                            }
                        }
                        .frame(height: Tokens.Size.scrubberBar)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { onScrub(Self.fraction($0.location.x, proxy.size.width), false) }
                .onEnded { onScrub(Self.fraction($0.location.x, proxy.size.width), true) })
        }
        .frame(height: Tokens.Size.touch)
        .accessibilityElement()
        .accessibilityLabel("Step \(stepIndex + 1) of \(phase.steps.count)")
        .accessibilityValue(Self.time(t, of: Timeline.duration(of: phase)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onNext()
            case .decrement: onPrevious()
            @unknown default: break
            }
        }
        .accessibilityIdentifier("playback.scrubber")
    }

    private static func fraction(_ x: CGFloat, _ width: CGFloat) -> Double {
        width > 0 ? Double(x / width) : 0
    }

    private var note: some View {
        let steps = phase.steps
        let text = steps.indices.contains(stepIndex) ? steps[stepIndex].note : nil
        let lead = Text(verbatim: "Step \(stepIndex + 1) of \(steps.count)" + (text == nil ? "" : " · "))
            .font(Tokens.Typeface.caption)
            .foregroundStyle(Tokens.Colour.muted.color)
        let written = Text(verbatim: text ?? "")
            .font(Tokens.Typeface.note)
            .foregroundStyle(Tokens.Colour.text.color)
        return Text("\(lead)\(written)")
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.s1)
            .accessibilityIdentifier("playback.note")
    }

    /// "0:04.2 / 0:06.5": the timeline's own length (MOCKUP-GAPS 17), not the export's.
    static func time(_ t: Double, of duration: Double) -> String {
        func clock(_ s: Double) -> String {
            // A summed duration lands a hair under its tenth (6.4999…), so nudge before flooring.
            let tenths = Int((max(s, 0) * 10 + 1e-6).rounded(.down))
            let seconds = tenths / 10
            return String(format: "%d:%02d.%d", seconds / 60, seconds % 60, tenths % 10)
        }
        return "\(clock(t)) / \(clock(duration))"
    }

    // MARK: Controls

    private var controls: some View {
        HStack(alignment: .top, spacing: 0) {
            icon("repeat", label: "Loop", identifier: "playback.loop", tint: loops ? Tokens.Colour.accent : Tokens.Colour.muted,
                 action: onLoop)
                .accessibilityAddTraits(loops ? .isSelected : [])
            icon("backward.end.fill", label: "Previous step", identifier: "playback.prev", action: onPrevious)
            Button(action: onToggle) {
                VStack(spacing: Tokens.Space.s1) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(Tokens.Typeface.title)
                        .foregroundStyle(Tokens.Colour.accentInk.color)
                        .frame(width: Tokens.Size.playDisc, height: Tokens.Size.playDisc)
                        .background(Tokens.Colour.accent.color, in: Circle())
                        .padding(.top, -Tokens.Space.s2 + 2)
                    Text(isPlaying ? "Pause" : "Play")
                        .font(Tokens.Typeface.caption)
                        .foregroundStyle(Tokens.Colour.text.color)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")
            .accessibilityShowsLargeContentViewer {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
            }
            .accessibilityIdentifier("playback.toggle")
            icon("forward.end.fill", label: "Next step", identifier: "playback.next", action: onNext)
            CapsuleSegments(options: [
                .init(value: 0.5, title: "½×", identifier: "playback.speed.half"),
                .init(value: 1.0, title: "1×", identifier: "playback.speed.one"),
            ], selection: Binding(get: { speed }, set: { onSpeed($0) }))
            .frame(width: 104)
            .accessibilityLabel("Speed")
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.top, Tokens.Space.s2)
        .frame(height: Tokens.Size.toolbarHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Tokens.Colour.surface.color.ignoresSafeArea(edges: .bottom))
        // The board toolbar's rule: capped like a tab bar, with the Large Content Viewer beyond it (D6-3).
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func icon(_ symbol: String, label: String, identifier: String, tint: RGBA = Tokens.Colour.text,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Tokens.Typeface.title.weight(.semibold))
                .foregroundStyle(tint.color)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.touch + Tokens.Space.s2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer { Label(label, systemImage: symbol) }
        .accessibilityIdentifier(identifier)
    }
}
