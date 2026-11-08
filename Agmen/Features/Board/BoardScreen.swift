import Combine
import SwiftUI

/// The board editor (UI-BRIEF §4.2): nav bar, pitch, the row under it, the steps strip and the toolbar.
/// Every edit goes through `DocumentEditor`, so it lands in the document and can be undone.
struct BoardScreen: View {
    @Binding var document: TacticDocument
    /// The board's own undo history (D-56), held by `TacticEditorHost`.
    let undoManager: UndoManager?

    @State var stepIndex = 0
    @State var selection: String?
    @State var showsStepActions = false
    @State var sheet: BoardSheet?
    @State var toast: BoardToast?
    @State var dragPreview: DragPreview?
    @State var pulse = 0
    @State var renaming = false
    @State var newTitle = ""
    @State var canUndo = false
    @State var canRedo = false
    /// The screen's width, so the title menu can truncate between the back button and the trailing items.
    @State var width: CGFloat = 0
    /// The pitch's width on screen (not the canvas's, which is wider when the pitch is fitted by height): the step
    /// PNG is twice it in pixels (SPEC §7).
    @State var boardWidth: CGFloat = 0
    /// Editing, playing the move (D4-1) or drawing on it (D4-2).
    @State var mode = BoardMode.editing
    /// Loop starts on, as in the mockup's playback frame; later sessions keep the last choice.
    @State var clock = PlaybackClock(duration: 0, loops: true)
    /// Whether the move was playing when the scrubber was grabbed, so it plays on when let go.
    @State var scrub: (resumes: Bool, active: Bool) = (false, false)
    @State var drawTool = DrawTool.run
    /// Draw mode's marks (D-65): the selected one, the line being tapped out, the box under the finger.
    @State var selectedMark: String?
    @State var lineDraft = LineDraft()
    @State var zonePreview: Zone?
    /// Draw's arrows (D-72): the Shape switch, the selected bent arrow and its dot under the finger.
    @State var arrowEdit = ArrowEditing()
    /// Edits made since draw mode opened (strokes, and on iPad the finger's token moves), so Cancel can take them
    /// all back (the mockup's "without changes").
    @State var drawEdits = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.dismiss) var dismiss
    /// The screen's whole height (nav bar included, so hiding it can't flip the layout) and width (D-73).
    @State var container = CGSize.zero

    struct DragPreview: Equatable {
        let id: String
        let point: Point
    }

    var editor: DocumentEditor {
        DocumentEditor(document: $document, undoManager: undoManager,
                       onTooBig: { show("This move is full. Remove a step or some lines to add more.") })
    }
    var tactic: Tactic { document.tactic }
    var steps: [Step] { tactic.phases.first?.steps ?? [] }
    /// The step on screen, kept in range when an undo removes steps.
    var current: Int { min(stepIndex, max(steps.count - 1, 0)) }
    var selectedToken: Token? { tactic.tokens.first { $0.id == selection } }
    var layout: BoardLayout { BoardLayout(sizeClass: sizeClass, size: container) }

    private var boardState: BoardState {
        var state = Timeline.restingState(step: current, in: shownTactic)
        if let dragPreview {
            state.positions[dragPreview.id] = dragPreview.point.clamped
            state.carry = [:]  // stale once a token moves; the renderer works the same weight out from distance
        }
        return state
    }

    var body: some View {
        layoutBody
            .background(Tokens.Colour.bg.color.ignoresSafeArea())
            .onGeometryChange(for: CGSize.self) { proxy in
                CGSize(width: proxy.size.width,
                       height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
            } action: { size in
                width = size.width
                container = size
            }
            .navigationTitle(tactic.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(mode == .drawing)
            .toolbar { navigationItems }
            .toolbar(layout == .regularLandscape ? .hidden : .automatic, for: .navigationBar)
            .onChange(of: tactic) { if mode == .playing { clock.setDuration(phaseDuration, at: Self.now) } }
            .onChange(of: drawTool) { changeTool() }
            .task(id: clock) { await pauseAtTheEnd() }
            .alert("Rename tactic", isPresented: $renaming) {
                TextField("Title", text: $newTitle)
                Button("Cancel", role: .cancel) {}
                Button("Rename") { rename(to: newTitle) }
                    .accessibilityIdentifier("rename.save")
            }
            .sheet(item: $sheet) { sheet in sheetContent(sheet) }
            .onReceive(undoChanges) { _ in refreshUndo() }
            .onAppear {
                refreshUndo()
                if tactic.tokens.isEmpty { sheet = .formation }
            }
    }

    /// iPhone and narrow windows keep the compact board; a regular-width screen uses the big-screen layouts (D-73).
    @ViewBuilder private var layoutBody: some View {
        switch layout {
        case .compact: compactBody
        case .regularPortrait: regularPortrait
        case .regularLandscape: regularLandscape
        }
    }

    private var compactBody: some View {
        VStack(spacing: 0) {
            pitchStack(nil)
                .padding(.top, Tokens.Space.s2)

            switch mode {
            case .editing: editingBar
            case .playing: playbackBar
            case .drawing:
                DrawPanel(tool: $drawTool, shape: shapeBinding, selectedMark: selectedMarkLabel,
                          onRemoveMark: removeSelectedMark, hint: arrowHint)
            }
        }
    }

    /// The pitch with the empty state and the toast over it. `size` frames the board to hug the pitch (iPad);
    /// nil keeps the iPhone's inset board.
    func pitchStack(_ size: CGSize?) -> some View {
        ZStack(alignment: .bottom) {
            sizedBoard(size)
            if tactic.tokens.isEmpty, mode == .editing { emptyState }
            if let toast {
                BoardToastView(toast: toast) { undoFromToast(toast) }
                    .padding(.horizontal, Tokens.Space.s4)
                    .padding(.bottom, Tokens.Space.s2)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: BoardToast.lifetime)
                        withAnimation(Tokens.Motion.ease(Tokens.Motion.toast)) { self.toast = nil }
                    }
            }
        }
    }

    @ViewBuilder private func sizedBoard(_ size: CGSize?) -> some View {
        let measured = board
            .onGeometryChange(for: CGFloat.self) { [kind = tactic.pitch.kind] proxy in
                BoardGeometry(kind: kind, fitting: CGRect(origin: .zero, size: proxy.size)).pitchRect.width
            } action: { boardWidth = $0 }
        if let size {
            measured.frame(width: size.width, height: size.height)
        } else {
            measured.padding(.horizontal, Tokens.Space.s5)
        }
    }

    // MARK: Parts

    /// The pitch for the current mode: at rest on the step while editing and drawing, the timeline while playing.
    @ViewBuilder private var board: some View {
        if mode == .playing {
            TimelineView(.animation(minimumInterval: nil, paused: !clock.isPlaying)) { _ in
                let frame = PlaybackTrack.frame(at: clock.t(at: Self.now), in: tactic, reduceMotion: reduceMotion)
                canvas(frame.base, crossfade: frame.next.map { ($0, frame.mix) })
            }
        } else {
            canvas(boardState, crossfade: nil)
        }
    }

    private func canvas(_ state: BoardState, crossfade: (state: BoardState, mix: Double)?) -> some View {
        let drawing = mode == .drawing
        return BoardCanvas(
            tactic: tactic, state: state, selection: mode == .playing ? nil : selectedToken?.id,
            dimsUnselected: sheet?.isPlayer == true, crossfade: crossfade,
            movesTokens: mode == .editing || (drawing && Self.pencilDraws),
            strokeInput: strokeInput, strokeKind: drawTool.arrowKind ?? .run,
            selectedMark: drawing ? selectedMark : nil, pendingLine: drawing ? lineDraft.tokens : [],
            zonePreview: drawing ? zonePreview : nil, marking: boardMarking,
            showsMarks: mode != .playing, markActions: drawing ? markActions : nil, bending: boardBending,
            onStroke: drawStroke, onTap: tapBoard, onDoubleTap: doubleTapBoard,
            onDrag: { id, point in dragPreview = DragPreview(id: id, point: point) },
            onDragEnd: endDrag, onDragCancel: { dragPreview = nil }, onNudge: nudge
        )
    }

    @ViewBuilder private var editingBar: some View {
        contextRow(prominent: false)
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.vertical, Tokens.Space.s1)
            .animation(Tokens.Motion.ease(Tokens.Motion.select), value: contextKey)

        if !tactic.tokens.isEmpty {
            StepsStrip(steps: steps, current: current, pulse: pulse,
                       onSelect: selectStep, onAdd: { addStep("Add step") }, onMove: moveStep)
                .padding(.vertical, Tokens.Space.s1)
        }

        bottomToolbar(drawing: false)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.s4) {
            Text("Pick a formation to start")
                .font(Tokens.Typeface.title)
                .foregroundStyle(Tokens.Colour.text.color)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("board.empty.message")
            Button("Choose formation") { sheet = .formation }
                .buttonStyle(PrimaryCapsuleStyle())
                .accessibilityIdentifier("board.empty.pick")
        }
        .padding(.horizontal, Tokens.Space.s6 + Tokens.Space.s4)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder func contextRow(prominent: Bool) -> some View {
        if showsStepActions, steps.indices.contains(current) {
            BoardContextRow(
                mode: .step(number: current + 1, duration: steps[current].duration, canDelete: steps.count > 1),
                onDuration: setDuration, onDuplicate: { addStep("Duplicate step") },
                onNote: { sheet = .note(current) }, onDeleteStep: deleteStep, prominent: prominent
            )
        } else if let token = selectedToken {
            BoardContextRow(
                mode: .token(label: Self.selectionLabel(token), isPlayer: token.kind == .player),
                onEdit: { openPlayer(token.id) }, onDrawRun: { startDrawing(.run) },
                onRemove: { removeToken(token) }, prominent: prominent
            )
        } else {
            BoardContextRow(mode: .summary(tag: formationTag, step: stepSummary), prominent: prominent)
        }
    }

    var contextKey: String { "\(showsStepActions)-\(selection ?? "")" }

    private var formationTag: String {
        let players = tactic.tokens.filter { $0.kind == .player }.count
        if players == 0 { return "No players" }
        return FormationMatch.formation(of: tactic, in: Presets.shared.formations, step: current)?.name ?? "\(players) players"
    }

    private var stepSummary: String {
        let duration = steps.indices.contains(current) ? steps[current].duration : Step.defaultDuration
        return "Step \(current + 1) of \(max(steps.count, 1)) · \(BoardContextRow.seconds(duration))"
    }

    /// "3 · Full-back", "Ade · Winger", "Ball".
    static func selectionLabel(_ token: Token) -> String {
        switch token.kind {
        case .ball: return "Ball"
        case .cone: return "Cone"
        case .marker: return "Marker"
        case .player:
            let who = token.number.map(String.init) ?? token.name ?? (token.side == .away ? "Their player" : "Player")
            guard let role = Presets.shared.role(token.roleID) else { return who }
            return "\(who) · \(role.name)"
        }
    }

    @ViewBuilder private func sheetContent(_ sheet: BoardSheet) -> some View {
        switch sheet {
        case .player(let id):
            PlayerSheet(tokenID: id, editor: editor) { token in removeToken(token) }
        case .formation:
            FormationPicker(editor: editor, stepIndex: current)
        case .note(let index):
            StepNoteSheet(editor: editor, stepIndex: index)
        case .export:
            ExportSheet(tactic: tactic, stepIndex: current, boardWidth: boardWidth)
        }
    }
}
