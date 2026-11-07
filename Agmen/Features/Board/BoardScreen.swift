import Combine
import SwiftUI

/// The board editor (UI-BRIEF §4.2): nav bar, pitch, the row under it, the steps strip and the toolbar.
/// Every edit goes through `DocumentEditor`, so it lands in the document and can be undone.
struct BoardScreen: View {
    @Binding var document: TacticDocument
    @Environment(\.undoManager) var undoManager

    @State var stepIndex = 0
    @State var selection: String?
    @State var showsStepActions = false
    @State var sheet: BoardSheet?
    @State var toast: BoardToast?
    @State var dragPreview: DragPreview?
    @State var pulse = 0
    @State private var canUndo = false
    @State private var canRedo = false

    struct DragPreview: Equatable {
        let id: String
        let point: Point
    }

    var editor: DocumentEditor { DocumentEditor(document: $document, undoManager: undoManager) }
    var tactic: Tactic { document.tactic }
    var steps: [Step] { tactic.phases.first?.steps ?? [] }
    /// The step on screen, kept in range when an undo removes steps.
    var current: Int { min(stepIndex, max(steps.count - 1, 0)) }
    var selectedToken: Token? { tactic.tokens.first { $0.id == selection } }

    private var boardState: BoardState {
        var state = Timeline.restingState(step: current, in: tactic)
        if let dragPreview { state.positions[dragPreview.id] = dragPreview.point.clamped }
        return state
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                BoardCanvas(
                    tactic: tactic, state: boardState, selection: selectedToken?.id,
                    dimsUnselected: sheet?.isPlayer == true,
                    onTap: tap, onDoubleTap: openPlayer,
                    onDrag: { id, point in dragPreview = DragPreview(id: id, point: point) },
                    onDragEnd: endDrag, onDragCancel: { dragPreview = nil }, onNudge: nudge
                )
                .padding(.horizontal, Tokens.Space.s5)
                if tactic.tokens.isEmpty { emptyState }
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
                onPlay: { show("Playback comes on Day 4") }, onDraw: { show("Drawing comes on Day 4") },
                onExport: { show("Export comes on Day 5") }
            )
        }
        .background(Tokens.Colour.bg.color.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationItems }
        .toolbarTitleMenu { pitchMenu }
        .sheet(item: $sheet) { sheet in sheetContent(sheet) }
        .onReceive(undoChanges) { _ in refreshUndo() }
        .onAppear {
            refreshUndo()
            if tactic.tokens.isEmpty { sheet = .formation }
        }
    }

    // MARK: Parts

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
                onEdit: { openPlayer(token.id) }, onDrawRun: { show("Drawing runs comes on Day 4") },
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

    @ToolbarContentBuilder private var navigationItems: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                .disabled(!canUndo)
                .accessibilityIdentifier("nav.undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                .disabled(!canRedo)
                .accessibilityIdentifier("nav.redo")
        }
        // Share stays visible (D-55). Next to the document title there is room for three items, so the mockup's
        // "more" options (the pitch) live in the title menu instead.
        ToolbarItem(placement: .topBarTrailing) {
            Button("Share", systemImage: "square.and.arrow.up") { show("Sharing comes on Day 6") }
                .accessibilityIdentifier("nav.share")
        }
    }

    @ViewBuilder private var pitchMenu: some View {
        Picker("Pitch", selection: Binding(get: { tactic.pitch.kind }, set: setPitchKind)) {
            Text("11-a-side").tag(Pitch.Kind.full)
            Text("7-a-side").tag(Pitch.Kind.sevenASide)
            Text("5-a-side").tag(Pitch.Kind.fiveASide)
        }
        .pickerStyle(.menu)
        Picker("Pitch style", selection: Binding(get: { tactic.pitch.style }, set: setPitchStyle)) {
            Text("Stripes").tag(Pitch.Style.stripes)
            Text("Plain").tag(Pitch.Style.plain)
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder private func sheetContent(_ sheet: BoardSheet) -> some View {
        switch sheet {
        case .player(let id):
            PlayerSheet(tokenID: id, editor: editor) { token in removeToken(token) }
        case .formation:
            FormationPicker(editor: editor, stepIndex: current)
        case .note(let index):
            StepNoteSheet(editor: editor, stepIndex: index)
        }
    }

    // MARK: Undo state

    private var undoChanges: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.MergeMany(
            center.publisher(for: .NSUndoManagerDidCloseUndoGroup),
            center.publisher(for: .NSUndoManagerDidUndoChange),
            center.publisher(for: .NSUndoManagerDidRedoChange)
        )
        .eraseToAnyPublisher()
    }

    private func refreshUndo() {
        canUndo = undoManager?.canUndo ?? false
        canRedo = undoManager?.canRedo ?? false
    }
}

/// The sheets the board can show.
enum BoardSheet: Identifiable, Hashable {
    case player(String)
    case formation
    case note(Int)

    var id: String {
        switch self {
        case .player(let id): "player-\(id)"
        case .formation: "formation"
        case .note(let index): "note-\(index)"
        }
    }

    var isPlayer: Bool { if case .player = self { true } else { false } }
}
