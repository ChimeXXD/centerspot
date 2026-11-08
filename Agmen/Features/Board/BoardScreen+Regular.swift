import SwiftUI

/// The board on a regular-width screen (D-73, mockup frames ipad-board--landscape, ipad-draw--landscape and
/// ipad-board--portrait). The pitch is sized to hug the pitch itself, so it is centred and as big as the space allows.
extension BoardScreen {
    /// Height over width of the pitch kind on screen.
    private var pitchAspect: CGFloat { BoardGeometry.height(forWidth: 1, kind: tactic.pitch.kind) }

    /// The pitch, fitted into whatever space it is given and centred there.
    var fittedPitch: some View {
        GeometryReader { proxy in
            let fit = BoardGeometry(kind: tactic.pitch.kind, fitting: CGRect(origin: .zero, size: proxy.size)).pitchRect
            pitchStack(fit.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    // MARK: Portrait

    /// The pitch as big as the height allows, then one row (steps on the left, the selection on the right), then the
    /// toolbar. Playback and Draw keep the iPhone's bars under the pitch.
    var regularPortrait: some View {
        VStack(spacing: 0) {
            fittedPitch
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.top, Tokens.Space.s2)
            switch mode {
            case .editing: portraitBar
            case .playing: playbackBar
            case .drawing:
                DrawPanel(tool: $drawTool, selectedMark: selectedMarkLabel, onRemoveMark: removeSelectedMark)
            }
        }
    }

    @ViewBuilder private var portraitBar: some View {
        HStack(spacing: Tokens.Space.s5) {
            if !tactic.tokens.isEmpty {
                let strip = StepsStrip(
                    steps: steps, current: current, pulse: pulse, onSelect: selectStep,
                    onAdd: { addStep("Add step") }, onMove: moveStep,
                    chipSize: CGSize(width: 56, height: 64), spacing: Tokens.Space.s2, inset: 0
                )
                strip.frame(maxWidth: strip.contentWidth)
            }
            contextRow(prominent: false)
                .frame(minWidth: 280)
                .animation(Tokens.Motion.ease(Tokens.Motion.select), value: contextKey)
        }
        .frame(height: 72)
        .padding(.horizontal, Tokens.Space.s5)
        .padding(.vertical, Tokens.Space.s1)
        bottomToolbar(drawing: false)
    }

    // MARK: Landscape

    /// The upright pitch fills the height on the left; the column on the right holds the nav row, every step (D-75),
    /// the selection or the draw tools. The toolbar runs along the bottom (hidden while playing, as on iPhone).
    var regularLandscape: some View {
        GeometryReader { proxy in
            let bottom = mode == .playing ? 0 : Tokens.Size.toolbarHeight
            let byHeight = (proxy.size.height - bottom - 2 * Tokens.Space.s2) / pitchAspect
            let pitchWidth = max(min(byHeight, proxy.size.width - 3 * Tokens.Space.s5 - BoardLayout.minimumColumn), 0)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: Tokens.Space.s5) {
                    fittedPitch.frame(width: pitchWidth)
                    column.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, Tokens.Space.s2)
                if mode != .playing { bottomToolbar(drawing: mode == .drawing) }
            }
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            columnNavRow
            if mode != .playing, !tactic.tokens.isEmpty {
                StepsList(steps: steps, current: current, onSelect: selectStepFromList,
                          onAdd: { addStep("Add step") }, onMove: moveStep)
                    .layoutPriority(1)
            }
            switch mode {
            case .editing:
                contextCard
            case .drawing:
                DrawPanel(tool: $drawTool, selectedMark: selectedMarkLabel, onRemoveMark: removeSelectedMark,
                          inColumn: true)
            case .playing:
                playbackBar.padding(.horizontal, -Tokens.Space.s5)
            }
            Spacer(minLength: 0)
        }
    }

    /// The mockup's row card: the selected player and their actions, a step's actions, or the formation and step.
    private var contextCard: some View {
        contextRow(prominent: true)
            .padding(.leading, Tokens.Space.s4 + 4)
            .padding(.trailing, Tokens.Space.s2 + 2)
            .padding(.vertical, Tokens.Space.s2 + 2)
            .frame(minHeight: 64)
            .background(Tokens.Colour.surface.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .animation(Tokens.Motion.ease(Tokens.Motion.select), value: contextKey)
    }

    /// In draw mode a row changes the step after finishing a line being tapped out; the current row does nothing
    /// there (its actions belong to editing).
    private func selectStepFromList(_ index: Int) {
        guard mode == .drawing else { return selectStep(index) }
        guard index != current else { return }
        finishLine()
        clearMarkState()
        selectStep(index)
    }

    /// The bottom toolbar; on iPad its items gather in the middle, and in landscape it stays in draw mode with Draw
    /// lit (tapping it again finishes, like Done).
    func bottomToolbar(drawing: Bool) -> some View {
        BoardToolbar(
            hasBall: tactic.tokens.contains { $0.kind == .ball },
            onFormation: { sheet = .formation }, onAdd: addToken,
            onPlay: startPlayback, onDraw: { if mode == .drawing { finishDrawing() } else { startDrawing() } },
            onExport: { sheet = .export }, drawing: drawing,
            itemsWidth: layout == .compact ? .infinity : 700
        )
    }
}
