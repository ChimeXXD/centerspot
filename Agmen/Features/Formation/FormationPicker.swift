import SwiftUI

/// The formation sheet (D-48, mockup "formation"): 11 / 7 / 5-a-side tabs, chalk dot diagrams with the chosen one
/// outlined in lime, and "Use 4-3-3". On a board that already has players it asks first; names and numbers stay, and
/// a smaller shape says how many players leave the board (D-83).
struct FormationPicker: View {
    let editor: DocumentEditor
    let stepIndex: Int
    /// Called after a shape removed players, with how many, so the board can offer Undo.
    var onRemoved: (Int) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var size: Pitch.Kind = .full
    @State private var chosen: String?
    @State private var confirming = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s3), count: 3)

    private var shapes: [Formation] { Presets.shared.formations.filter { $0.pitch == size } }
    private var formation: Formation? { shapes.first { $0.id == chosen } ?? shapes.first }
    private var hasPlayers: Bool { editor.tactic.tokens.contains { $0.kind == .player && $0.side == .home } }

    var body: some View {
        ScrollView {
            VStack(spacing: Tokens.Space.s4) {
                SheetHeader(title: "Formation", closeIdentifier: "formation.close") { dismiss() }
                CapsuleSegments(options: [
                    .init(value: Pitch.Kind.full, title: "11-a-side", identifier: "formation.size.full"),
                    .init(value: .sevenASide, title: "7-a-side", identifier: "formation.size.seven"),
                    .init(value: .fiveASide, title: "5-a-side", identifier: "formation.size.five"),
                ], selection: $size)
                LazyVGrid(columns: columns, spacing: Tokens.Space.s3) {
                    ForEach(shapes) { shape in tile(shape) }
                }
            }
            .padding(.horizontal, Tokens.Space.s5)
            .padding(.top, Tokens.Space.s5)
            .padding(.bottom, Tokens.Space.s4)
        }
        // 18 eleven-a-side shapes (D-63) scroll; "Use" stays in reach under them.
        .safeAreaInset(edge: .bottom) {
            if let formation {
                Button("Use \(formation.name)") { hasPlayers ? (confirming = true) : apply(formation) }
                    .buttonStyle(PrimaryCapsuleStyle())
                    .accessibilityIdentifier("formation.apply")
                    .padding(.horizontal, Tokens.Space.s5)
                    .padding(.top, Tokens.Space.s3)
                    .padding(.bottom, Tokens.Space.s2)
                    .background(Tokens.Colour.surface.color)
            }
        }
        .onAppear {
            size = editor.tactic.pitch.kind
            chosen = FormationMatch.formation(of: editor.tactic, in: Presets.shared.formations)?.id
        }
        .onChange(of: size) { _, _ in
            if !shapes.contains(where: { $0.id == chosen }) { chosen = shapes.first?.id }
        }
        .alert("Move players to \(formation?.name ?? "")?", isPresented: $confirming) {
            Button("Move") { if let formation { apply(formation) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
        .presentationDetents([.fraction(0.8), .large])
        .agmenSheet()
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
