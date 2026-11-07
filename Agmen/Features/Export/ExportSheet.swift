import SwiftUI

/// The export sheet (UI-BRIEF §4.6, mockup "export", "export--rendering", "export--done", "export--error"): the
/// preview beside the preset tiles and switches, the estimate before export, an honest frame count while rendering
/// with Cancel, the real size before the share sheet, and a way out of an error.
struct ExportSheet: View {
    @State private var model: ExportModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(tactic: Tactic, stepIndex: Int, boardWidth: CGFloat) {
        _model = State(initialValue: ExportModel(tactic: tactic, stepIndex: stepIndex, boardWidth: boardWidth))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: "Export", closeIdentifier: "export.close") { dismiss() }
                    .padding(.bottom, Tokens.Space.s4)
                // Side by side, or the preview above the choices at the accessibility sizes, where the narrow column
                // broke words mid-way ("Renderi / ng", D6-3).
                let stacked = dynamicTypeSize.isAccessibilitySize
                let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: Tokens.Space.s4))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: Tokens.Space.s4))
                layout {
                    ExportPreview(model: model)
                        .frame(maxWidth: stacked ? .infinity : nil)
                    side
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if model.phase == .choosing, model.preset.video == nil { extras.padding(.top, Tokens.Space.s4) }
                footer
                    .padding(.top, Tokens.Space.s5)
            }
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s5)
            .padding(.bottom, Tokens.Space.s4)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Between states only: animating every frame count would crossfade the digits.
        .animation(Tokens.Motion.ease(Tokens.Motion.step), value: stage)
        .onDisappear { model.close() }
        .interactiveDismissDisabled(isRendering)
        .presentationDetents([.fraction(0.7), .large])
        .agmenSheet()
    }

    private var isRendering: Bool { stage == 1 }

    /// Which state the sheet is in, ignoring the frame count.
    private var stage: Int {
        switch model.phase {
        case .choosing: 0
        case .rendering: 1
        case .finished: 2
        case .failed: 3
        }
    }

    // MARK: Beside the preview

    @ViewBuilder private var side: some View {
        switch model.phase {
        case .choosing:
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                ExportPresetTiles(selection: $model.preset)
                Toggle("Title band", isOn: $model.showsTitle)
                    .accessibilityIdentifier("export.title-band")
                Toggle("Step notes", isOn: $model.showsNotes)
                    .accessibilityIdentifier("export.notes")
            }
            .toggleStyle(.switch)
            .tint(Tokens.Colour.accent.color)
            .font(Tokens.Typeface.headline)
            .foregroundStyle(Tokens.Colour.text.color)
        case .rendering:
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(model.progressText)
                    .font(Tokens.Typeface.headline)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .accessibilityIdentifier("export.progress")
                Text(model.remainingText)
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .accessibilityIdentifier("export.progress-help")
                ProgressBar(value: model.progress)
                    .padding(.top, Tokens.Space.s3)
                    .accessibilityIdentifier("export.progress-bar")
            }
            .padding(.top, Tokens.Space.s5)
        case .finished(let file):
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(file.isVideo ? "Video ready" : "Image ready")
                    .font(Tokens.Typeface.title)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .accessibilityIdentifier("export.done")
                Text(file.summary)
                    .font(Tokens.Typeface.body)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .accessibilityIdentifier("export.done-size")
            }
            .padding(.top, Tokens.Space.s5)
        case .failed:
            Text(model.preset.video == nil ? "Couldn't make the image. Try again." : "Couldn't make the video. Try again, or export an image.")
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .padding(.top, Tokens.Space.s5)
                .accessibilityIdentifier("export.error")
        }
    }

    /// Under the preview for an image (D-63): the step or the lineup card. Videos have nothing here since Spotlight was
    /// dropped (D-66); glow rings on a player do that job per step.
    private var extras: some View {
        CapsuleSegments(options: [
            .init(value: ExportModel.ImageKind.step, title: "Step \(model.stepIndex + 1)", identifier: "export.image.step"),
            .init(value: .lineup, title: "Lineup card", identifier: "export.image.lineup"),
        ], selection: $model.imageKind)
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        switch model.phase {
        case .choosing:
            VStack(alignment: .leading, spacing: 2) {
                Text(model.estimate)
                    .font(Tokens.Typeface.headline)
                    .foregroundStyle(Tokens.Colour.text.color)
                    .accessibilityIdentifier("export.size")
                Text(model.estimateHelp)
                    .font(Tokens.Typeface.caption)
                    .foregroundStyle(Tokens.Colour.muted.color)
                    .accessibilityIdentifier("export.size-help")
                Button(model.preset.video == nil ? "Export image" : "Export video") { model.start() }
                    .buttonStyle(PrimaryCapsuleStyle())
                    .padding(.top, Tokens.Space.s3)
                    .accessibilityIdentifier("export.start")
            }
        case .rendering:
            Button("Cancel") { model.cancel() }
                .buttonStyle(QuietCapsuleStyle())
                .accessibilityIdentifier("export.cancel")
        case .finished(let file):
            VStack(spacing: Tokens.Space.s2 + 2) {
                ShareLink(item: file.url) { Text(file.isVideo ? "Share video" : "Share image") }
                    .buttonStyle(PrimaryCapsuleStyle())
                    .accessibilityIdentifier("export.share")
                Button(photosTitle) { Task { await model.saveToPhotos() } }
                    .buttonStyle(QuietCapsuleStyle())
                    .disabled(model.photos == .saving || model.photos == .saved)
                    .accessibilityIdentifier("export.save")
            }
        case .failed:
            VStack(spacing: Tokens.Space.s2 + 2) {
                Button("Try again") { model.start() }
                    .buttonStyle(PrimaryCapsuleStyle())
                    .accessibilityIdentifier("export.retry")
                if model.preset.video != nil {
                    Button("Export an image") { model.chooseImage() }
                        .buttonStyle(QuietCapsuleStyle())
                        .accessibilityIdentifier("export.image")
                }
            }
        }
    }

    private var photosTitle: String {
        switch model.photos {
        case .idle, .saving: "Save to Photos"
        case .saved: "Saved to Photos"
        case .failed: "Couldn't save. Allow Photos in Settings"
        }
    }
}

/// The four preset tiles (mockup): a ratio outline over the name, lime outline on the chosen one.
private struct ExportPresetTiles: View {
    @Binding var selection: ExportModel.Preset
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let shapes: [ExportModel.Preset: CGSize] = [
        .vertical: CGSize(width: 14, height: 24), .square: CGSize(width: 21, height: 21),
        .wide: CGSize(width: 26, height: 14), .image: CGSize(width: 21, height: 18),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Tokens.Space.s2), GridItem(.flexible())],
                  spacing: Tokens.Space.s2) {
            ForEach(ExportModel.Preset.allCases) { preset in
                let on = preset == selection
                Button { selection = preset } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Tokens.Colour.text.color, lineWidth: 2)
                            .frame(width: Self.shapes[preset]?.width, height: Self.shapes[preset]?.height)
                        Text(preset.title)
                            .font(Tokens.Typeface.caption.weight(.bold))
                            .foregroundStyle(Tokens.Colour.text.color)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                            .strokeBorder(on ? Tokens.Colour.accent.color : .clear, lineWidth: 2)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("export.preset.\(preset.rawValue)")
            }
        }
    }
}

/// A lime bar on a dark track (the mockup's progress bar).
private struct ProgressBar: View {
    let value: Double

    var body: some View {
        Capsule()
            .fill(Tokens.Colour.surface3.color)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(Tokens.Colour.accent.color).frame(width: proxy.size.width * min(max(value, 0), 1))
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
    }
}
