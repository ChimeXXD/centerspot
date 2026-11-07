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
    @State var drawKind = Arrow.Kind.run
    /// Edits made since draw mode opened (strokes, and on iPad the finger's token moves), so Cancel can take them
    /// all back (the mockup's "without changes").
    @State var drawEdits = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

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

    private var boardState: BoardState {
        var state = Timeline.restingState(step: current, in: tactic)
        if let dragPreview {
            state.positions[dragPreview.id] = dragPreview.point.clamped
            state.carry = [:]  // stale once a token moves; the renderer works the same weight out from distance
        }
        return state
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                board
                    .onGeometryChange(for: CGFloat.self) { [kind = tactic.pitch.kind] proxy in
                        BoardGeometry(kind: kind, fitting: CGRect(origin: .zero, size: proxy.size)).pitchRect.width
                    } action: { boardWidth = $0 }
                    .padding(.horizontal, Tokens.Space.s5)
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
            .padding(.top, Tokens.Space.s2)

            switch mode {
            case .editing: editingBar
            case .playing: playbackBar
            case .drawing: DrawPanel(kind: $drawKind)
            }
        }
        .background(Tokens.Colour.bg.color.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .navigationTitle(tactic.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(mode == .drawing)
        .toolbar { navigationItems }
        .onChange(of: tactic) { if mode == .playing { clock.setDuration(phaseDuration, at: Self.now) } }
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
        BoardCanvas(
            tactic: tactic, state: state, selection: mode == .playing ? nil : selectedToken?.id,
            dimsUnselected: sheet?.isPlayer == true, crossfade: crossfade,
            movesTokens: mode == .editing || (mode == .drawing && Self.pencilDraws),
            strokeInput: strokeInput, strokeKind: drawKind, onStroke: drawStroke,
            onTap: tapBoard, onDoubleTap: doubleTapBoard,
            onDrag: { id, point in dragPreview = DragPreview(id: id, point: point) },
            onDragEnd: endDrag, onDragCancel: { dragPreview = nil }, onNudge: nudge
        )
    }

    @ViewBuilder private var editingBar: some View {
        contextRow
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.vertical, Tokens.Space.s1)
            .animation(Tokens.Motion.ease(Tokens.Motion.select), value: contextKey)

        if !tactic.tokens.isEmpty {
            StepsStrip(steps: steps, current: current, pulse: pulse,
                       onSelect: selectStep, onAdd: { addStep("Add step") }, onMove: moveStep)
                .padding(.vertical, Tokens.Space.s1)
        }

        BoardToolbar(
            hasBall: tactic.tokens.contains { $0.kind == .ball },
            onFormation: { sheet = .formation }, onAdd: addToken,
            onPlay: startPlayback, onDraw: { startDrawing() },
            onExport: { sheet = .export }
        )
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

    @ViewBuilder private var contextRow: some View {
        if showsStepActions, steps.indices.contains(current) {
            BoardContextRow(
                mode: .step(number: current + 1, duration: steps[current].duration, canDelete: steps.count > 1),
                onDuration: setDuration, onDuplicate: { addStep("Duplicate step") },
                onNote: { sheet = .note(current) }, onDeleteStep: deleteStep
            )
        } else if let token = selectedToken {
            BoardContextRow(
                mode: .token(label: Self.selectionLabel(token), isPlayer: token.kind == .player),
                onEdit: { openPlayer(token.id) }, onDrawRun: { startDrawing(.run) },
                onRemove: { removeToken(token) }
            )
        } else {
            BoardContextRow(mode: .summary(tag: formationTag, step: stepSummary))
        }
    }

    private var contextKey: String { "\(showsStepActions)-\(selection ?? "")" }

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

/// The sheets the board can show.
enum BoardSheet: Identifiable, Hashable {
    case player(String)
    case formation
    case note(Int)
    case export

    var id: String {
        switch self {
        case .player(let id): "player-\(id)"
        case .formation: "formation"
        case .note(let index): "note-\(index)"
        case .export: "export"
        }
    }

    var isPlayer: Bool { if case .player = self { true } else { false } }
}

/// What the board is doing: editing a step, playing the move (D4-1) or drawing on it (D4-2).
enum BoardMode: Equatable {
    case editing, playing, drawing
}
