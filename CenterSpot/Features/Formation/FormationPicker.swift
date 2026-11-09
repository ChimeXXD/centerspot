import SwiftUI

/// The formation sheet (D-48, mockup "formation"): 11 / 7 / 5-a-side tabs, chalk dot diagrams with the chosen one
/// outlined, and "Use 4-3-3". On a board that already has players it asks first; names and numbers stay, and a smaller
/// shape says how many players leave the board (D-83). The Scenarios tab (D-94, mockup `scenarios.html`) sets up a
/// situation for the chosen shape instead: both sides and the ball, attacking or defending.
struct FormationPicker: View {
    let editor: DocumentEditor
    let stepIndex: Int
    /// Called after a shape removed players, with how many, so the board can offer Undo.
    var onRemoved: (Int) -> Void = { _ in }
    /// Called after a scenario set up the board, with the toast's words, so the board can offer Undo.
    var onScenario: (String) -> Void = { _ in }

    enum Tab: Hashable, Sendable { case shapes, scenarios }

    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.shapes
    @State private var size: Pitch.Kind = .full
    @State private var chosen: String?
    @State private var confirming = false
    @State private var scenarioID: String?
    @State private var attacking = true
    @State private var confirmingScenario = false
    /// The scenario list's width: three tiles a row from 480 pt (an iPad's sheet), else two (mockup `scenarios-ipad`).
    @State private var listWidth: CGFloat = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s3), count: 3)

    private var shapes: [Formation] { Presets.shared.formations.filter { $0.pitch == size } }
    private var formation: Formation? { shapes.first { $0.id == chosen } ?? shapes.first }
    private var hasPlayers: Bool { editor.tactic.tokens.contains { $0.kind == .player && $0.side == .home } }
    private var scenario: Scenario? {
        guard let formation else { return nil }
        return Scenario.available(for: formation.pitch).first { $0.id == scenarioID }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Tokens.Space.s4) {
                SheetHeader(title: "Formation", closeIdentifier: "formation.close") { dismiss() }
                CapsuleSegments(options: [
                    .init(value: Tab.shapes, title: "Shapes", identifier: "formation.tab.shapes"),
                    .init(value: .scenarios, title: "Scenarios", identifier: "formation.tab.scenarios"),
                ], selection: $tab)
            }
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s5)
            ScrollView {
                Group {
                    switch tab {
                    case .shapes: shapesTab
                    case .scenarios: scenariosTab
                    }
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.top, Tokens.Space.s4)
                .padding(.bottom, Tokens.Space.s4)
            }
        }
        .safeAreaInset(edge: .bottom) { useButton }
        .onAppear {
            size = editor.tactic.pitch.kind
            chosen = FormationMatch.formation(of: editor.tactic, in: Presets.shared.formations)?.id
        }
        .onChange(of: size) { _, _ in
            if !shapes.contains(where: { $0.id == chosen }) { chosen = shapes.first?.id }
            if scenario == nil { scenarioID = nil }
        }
        .alert("Move players to \(formation?.name ?? "")?", isPresented: $confirming) {
            Button("Move") { if let formation { apply(formation) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .alert("Set up \(scenario?.name ?? "")?", isPresented: $confirmingScenario) {
            Button("Cancel", role: .cancel) {}
            Button("Set up") { applyScenario() }
        } message: {
            Text("This replaces the move on the board. You can undo.")
        }
        .presentationDetents([.fraction(0.8), .large])
        .centerSpotSheet()
    }

    // MARK: Shapes

    private var shapesTab: some View {
        VStack(spacing: Tokens.Space.s4) {
            CapsuleSegments(options: [
                .init(value: Pitch.Kind.full, title: "11-a-side", identifier: "formation.size.full"),
                .init(value: .sevenASide, title: "7-a-side", identifier: "formation.size.seven"),
                .init(value: .fiveASide, title: "5-a-side", identifier: "formation.size.five"),
            ], selection: $size)
            // 18 eleven-a-side shapes (D-63) scroll; "Use" stays in reach under them.
            LazyVGrid(columns: columns, spacing: Tokens.Space.s3) {
                ForEach(shapes) { shape in tile(shape) }
            }
        }
    }

    private func tile(_ shape: Formation) -> some View {
        let on = shape.id == formation?.id
        return Button { chosen = shape.id } label: {
            VStack(spacing: Tokens.Space.s2) {
                FormationDiagram(formation: shape)
                    .frame(width: 74, height: 92)
                Text(shape.name)
                    .font(Tokens.Typeface.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Colour.text.color)
            }
            .frame(maxWidth: .infinity, minHeight: 128)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                    .strokeBorder(on ? Tokens.Colour.text.color : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shape.name)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("formation.\(shape.id)")
    }

    // MARK: Scenarios

    /// "2-3-1 (7-a-side)" → "2-3-1": the size is said beside it.
    private static func shortName(_ shape: Formation) -> String {
        shape.name.replacingOccurrences(of: #"\s*\(.*\)$"#, with: "", options: .regularExpression)
    }

    private static func sizeName(_ kind: Pitch.Kind) -> String {
        switch kind {
        case .full: "11-a-side"
        case .sevenASide: "7-a-side"
        case .fiveASide: "5-a-side"
        }
    }

    @ViewBuilder private var scenariosTab: some View {
        if let formation {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                shapeChip(formation)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { listWidth = $0 }
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    CapsuleSegments(options: [
                        .init(value: true, title: "Attacking", identifier: "scenario.side.attacking"),
                        .init(value: false, title: "Defending", identifier: "scenario.side.defending"),
                    ], selection: $attacking)
                    Text(attacking ? "You have the ball. Lime is your team." : "They have the ball. Lime is your team.")
                        .font(Tokens.Typeface.caption)
                        .foregroundStyle(Tokens.Colour.muted.color)
                        .padding(.leading, Tokens.Space.s1)
                        .accessibilityIdentifier("scenario.side.help")
                }
                let offered = Scenario.available(for: formation.pitch)
                ForEach(Scenario.Group.allCases, id: \.self) { group in
                    let items = offered.filter { $0.group == group }
                    if !items.isEmpty { scenarioGroup(group, items, formation: formation) }
                }
            }
        }
    }

    private func shapeChip(_ formation: Formation) -> some View {
        let name = Self.shortName(formation), size = Self.sizeName(formation.pitch)
        return Button { tab = .shapes } label: {
            HStack(spacing: 6) {
                Text(name).font(Tokens.Typeface.body.weight(.bold))
                Text(size).font(Tokens.Typeface.caption).foregroundStyle(Tokens.Colour.muted.color)
                Image(systemName: "chevron.right").font(Tokens.Typeface.caption.weight(.bold))
            }
            .foregroundStyle(Tokens.Colour.text.color)
            .padding(.leading, Tokens.Space.s4)
            .padding(.trailing, 14)
            .frame(minHeight: Tokens.Size.touch)
            .background(Tokens.Colour.surface2.color, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your shape, \(name), \(size). Change it")
        .accessibilityIdentifier("scenario.shape")
    }

    private func scenarioGroup(_ group: Scenario.Group, _ items: [Scenario], formation: Formation) -> some View {
        let count = listWidth >= 480 ? 3 : 2
        return VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(group.rawValue)
                .font(Tokens.Typeface.headline)
                .foregroundStyle(Tokens.Colour.text.color)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("scenario.group.\(group.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"))")
            // A Grid, not a lazy one: every tile in a row as tall as the tallest (a wrapped title), as in the mockup.
            Grid(horizontalSpacing: Tokens.Space.s3, verticalSpacing: Tokens.Space.s3) {
                ForEach(Array(stride(from: 0, to: items.count, by: count)), id: \.self) { start in
                    GridRow(alignment: .top) {
                        ForEach(items[start..<min(start + count, items.count)]) { item in
                            scenarioTile(item, formation: formation)
                        }
                        ForEach(0..<(count - min(count, items.count - start)), id: \.self) { _ in
                            Color.clear.gridCellUnsizedAxes(.vertical)
                        }
                    }
                }
            }
        }
        .padding(.top, Tokens.Space.s1)
    }

    private func scenarioTile(_ item: Scenario, formation: Formation) -> some View {
        let on = item.id == scenarioID
        let isTeam = if case .team = item.build { true } else { false }
        return Button { scenarioID = item.id } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let board = item.build(with: formation, attacking: attacking) {
                    ScenarioPicture(board: board, kind: formation.pitch, framesThePlay: !isTeam,
                                    move: ScenarioMotion.build(item, formation: formation, attacking: attacking), plays: on)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Tokens.Typeface.cardTitle.weight(.bold))
                        .foregroundStyle(Tokens.Colour.text.color)
                    Text(item.line)
                        .font(Tokens.Typeface.caption)
                        .foregroundStyle(Tokens.Colour.muted.color)
                        .lineLimit(2, reservesSpace: true)
                }
                .padding(.horizontal, Tokens.Space.s1)
            }
            .padding(.horizontal, Tokens.Space.s2)
            .padding(.top, Tokens.Space.s2)
            .padding(.bottom, Tokens.Space.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.tile))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.tile)
                    .strokeBorder(on ? Tokens.Colour.text.color : .clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityHint(item.line)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("scenario.\(item.id)")
    }

    // MARK: Use

    @ViewBuilder private var useButton: some View {
        Group {
            switch tab {
            case .shapes:
                if let formation {
                    Button("Use \(formation.name)") { hasPlayers ? (confirming = true) : apply(formation) }
                        .buttonStyle(PrimaryCapsuleStyle())
                }
            case .scenarios:
                if let scenario {
                    Button("Use \(scenario.name)") { hasMove ? (confirmingScenario = true) : applyScenario() }
                        .buttonStyle(PrimaryCapsuleStyle())
                } else {
                    Button("Pick a scenario") {}
                        .buttonStyle(QuietCapsuleStyle(foreground: Tokens.Colour.muted.color))
                        .disabled(true)
                }
            }
        }
        .accessibilityIdentifier("formation.apply")
        .padding(.horizontal, Tokens.Space.s5)
        .padding(.top, Tokens.Space.s3)
        .padding(.bottom, Tokens.Space.s2)
        .background(Tokens.Colour.surface.color)
    }

    /// Something to replace (D-96: the scenario's move replaces it): players, more than one step, or anything drawn or
    /// written on the one there is.
    private var hasMove: Bool {
        guard let steps = editor.tactic.phases.first?.steps else { return false }
        let first = steps.first
        return editor.tactic.tokens.contains { $0.kind == .player } || steps.count > 1
            || first.map { !$0.arrows.isEmpty || !$0.runs.isEmpty || $0.marks != Marks() || !($0.note ?? "").isEmpty } ?? false
    }

    private var extras: Int { formation.map { Formation.extraPlayers(in: editor.tactic, for: $0) } ?? 0 }

    private var confirmMessage: String {
        switch extras {
        case 0: "Names and numbers stay."
        case 1: "Names and numbers stay. 1 player leaves the board."
        default: "Names and numbers stay. \(extras) players leave the board."
        }
    }

    private func apply(_ formation: Formation) {
        let removed = Formation.extraPlayers(in: editor.tactic, for: formation)
        let applied = editor.apply("Change formation") { $0 = formation.apply(to: $0, stepIndex: stepIndex) }
        dismiss()
        // A refused edit (too big, D-69) removed no one: a toast's Undo would undo the edit before it.
        if applied, removed > 0 { onRemoved(removed) }
    }

    private func applyScenario() {
        guard let scenario, let formation else { return }
        let before = editor.tactic
        let applied = editor.apply("Set up \(scenario.name.lowercased())") {
            $0 = scenario.apply(to: $0, formation: formation, attacking: attacking, stepIndex: stepIndex)
        }
        dismiss()
        // An edit that changed nothing registered no undo: a toast's Undo would undo the edit before it.
        guard applied, editor.tactic != before else { return }
        // A board kept full by cones can't take every player (30 tokens, D-69): say so rather than claim it's set up.
        let wanted = scenario.build(with: formation, attacking: attacking).map { $0.home.count + $0.away.count } ?? 0
        let missing = wanted - editor.tactic.tokens.filter { $0.kind == .player }.count
        onScenario(missing > 0 ? "\(scenario.name) set up. \(missing) \(missing == 1 ? "player" : "players") didn't fit"
                               : "\(scenario.name) set up")
    }
}

/// A chalk dot diagram of a formation: outline, halfway line, one dot per slot (attacking upward).
struct FormationDiagram: View {
    let formation: Formation

    var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            let chalk = Tokens.Colour.chalk.color
            context.stroke(SwiftUI.Path(roundedRect: frame, cornerRadius: 4), with: .color(chalk), lineWidth: 1)
            var halfway = SwiftUI.Path()
            halfway.move(to: CGPoint(x: frame.minX, y: frame.midY))
            halfway.addLine(to: CGPoint(x: frame.maxX, y: frame.midY))
            context.stroke(halfway, with: .color(chalk), lineWidth: 1)
            let dot: CGFloat = 3.6, inset: CGFloat = 4
            let geometry = BoardGeometry(pitchRect: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset))
            for slot in formation.slots {
                let c = geometry.point(slot.point)
                context.fill(SwiftUI.Path(ellipseIn: CGRect(x: c.x - dot, y: c.y - dot, width: 2 * dot, height: 2 * dot)),
                             with: .color(Tokens.Colour.text.color))
            }
        }
        .accessibilityHidden(true)
    }
}
