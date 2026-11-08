import SwiftUI

/// The player sheet (UI-BRIEF §4.3, mockup "inspector"): name and number on one row, the role grouped by line, the side,
/// and Delete player. Name and number commit when the field loses focus or the sheet closes, as one undo step each.
struct PlayerSheet: View {
    let tokenID: String
    let editor: DocumentEditor
    var onDelete: (Token) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var number = ""
    @State private var line: Role.Line = .mid
    @FocusState private var focus: Field?

    private enum Field { case name, number }

    private var token: Token? { editor.tactic.tokens.first { $0.id == tokenID } }

    private static let lines: [(Role.Line, String)] = [
        (.gk, "Goalkeepers"), (.def, "Defenders"), (.mid, "Midfielders"), (.att, "Attackers"),
    ]

    var body: some View {
        if let token {
            ScrollView {
                VStack(spacing: 0) {
                    SheetHeader(title: title(token), closeIdentifier: "inspector.close") { commitAndClose() }
                        .padding(.bottom, Tokens.Space.s4)
                    fields
                    roles(token)
                    GroupLabel(text: "Side")
                        .padding(.bottom, Tokens.Space.s2)
                    // Setters are closures, never method references: Xcode 26.6 (Swift 6.3.3) crashes building the thunk.
                    CapsuleSegments(options: [
                        .init(value: Side.ID.home, title: "Us (filled)", identifier: "inspector.side.home"),
                        .init(value: Side.ID.away, title: "Them (ring)", identifier: "inspector.side.away"),
                    ], selection: Binding(get: { token.side ?? .home }, set: { setSide($0) }))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Side")
                    .accessibilityIdentifier("inspector.side")
                    Button("Delete player") { onDelete(token) }
                        .buttonStyle(QuietCapsuleStyle(foreground: Tokens.Colour.danger.color))
                        .accessibilityIdentifier("inspector.delete")
                        .padding(.top, Tokens.Space.s4)
                }
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.top, Tokens.Space.s5)
                .padding(.bottom, Tokens.Space.s6)
            }
            .onAppear {
                name = token.name ?? ""
                number = token.number.map(String.init) ?? ""
                line = Presets.shared.role(token.roleID)?.line ?? .mid
            }
            .onChange(of: focus) { old, _ in commit(old) }
            .onDisappear { commit(.name); commit(.number) }
            .presentationDetents([.fraction(0.72), .large])
            .agmenSheet()
        }
    }

    private func title(_ token: Token) -> String {
        if let number = token.number { return "Number \(number)" }
        return token.name ?? (token.side == .away ? "Their player" : "Player")
    }

    private var fields: some View {
        HStack(spacing: Tokens.Space.s3) {
            TextField("Name", text: $name)
                .focused($focus, equals: .name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { commit(.name) }
                .fieldStyle()
                .accessibilityLabel("Name")
                .accessibilityIdentifier("inspector.name")
            TextField("No.", text: $number)
                .focused($focus, equals: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .onChange(of: number) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(2))
                    if digits != new { number = digits }
                }
                .fieldStyle()
                .frame(width: 88)
                .accessibilityLabel("Shirt number")
                .accessibilityIdentifier("inspector.number")
        }
    }

    /// The roles of one line at a time, as in the mockup ("Role · Defenders"); the label switches line.
    private func roles(_ token: Token) -> some View {
        VStack(spacing: Tokens.Space.s2) {
            Menu {
                Picker("Line", selection: $line) {
                    ForEach(Self.lines, id: \.0) { Text($0.1).tag($0.0) }
                }
            } label: {
                HStack(spacing: Tokens.Space.s1) {
                    Text("Role · \(Self.lines.first { $0.0 == line }?.1 ?? "")")
                    Image(systemName: "chevron.down")
                }
                .font(Tokens.Typeface.caption)
                .foregroundStyle(Tokens.Colour.muted.color)
                .frame(maxWidth: .infinity, minHeight: Tokens.Size.touch - Tokens.Space.s2, alignment: .leading)
                .padding(.top, Tokens.Space.s2)
            }
            .accessibilityLabel("Role line, \(Self.lines.first { $0.0 == line }?.1 ?? "")")
            .accessibilityIdentifier("inspector.role-line")
            ForEach(Presets.shared.roles.filter { $0.line == line }) { role in
                let on = role.id == token.roleID
                Button { setRole(on ? nil : role.id) } label: {
                    HStack {
                        Text(role.name).font(Tokens.Typeface.body)
                        Spacer()
                        if on {
                            Image(systemName: "checkmark")
                                .font(Tokens.Typeface.inlineIcon)
                                .foregroundStyle(Tokens.Colour.text.color)
                        }
                    }
                    .foregroundStyle(Tokens.Colour.text.color)
                    .padding(.horizontal, Tokens.Space.s4)
                    .frame(minHeight: Tokens.Size.field)
                    .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
                    .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.item))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("inspector.role.\(role.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Role")
        .accessibilityIdentifier("inspector.role")
        .padding(.bottom, Tokens.Space.s1)
    }

    // MARK: Edits

    private func commit(_ field: Field?) {
        guard let token else { return }
        switch field {
        case .name:
            guard name.trimmingCharacters(in: .whitespacesAndNewlines) != (token.name ?? "") else { return }
            editor.apply("Rename player") { TacticEdits.setName(name, token: tokenID, in: &$0) }
        case .number:
            let value = Int(number)
            guard value != token.number else { return }
            editor.apply("Change number") { TacticEdits.setNumber(value, token: tokenID, in: &$0) }
        case nil:
            break
        }
    }

    private func commitAndClose() {
        commit(.name)
        commit(.number)
        dismiss()
    }

    private func setRole(_ roleID: String?) {
        editor.apply("Change role") { TacticEdits.setRole(roleID, token: tokenID, in: &$0) }
    }

    private func setSide(_ side: Side.ID) {
        editor.apply("Change side") { TacticEdits.setSide(side, token: tokenID, in: &$0) }
    }
}

private extension View {
    /// The mockup's `.field`: surface-2, 12 pt corners, 48 pt tall.
    func fieldStyle() -> some View {
        font(Tokens.Typeface.body)
            .foregroundStyle(Tokens.Colour.text.color)
            .padding(.horizontal, Tokens.Space.s4)
            .frame(minHeight: Tokens.Size.field)
            .background(Tokens.Colour.surface2.color, in: RoundedRectangle(cornerRadius: Tokens.Radius.item))
    }
}
