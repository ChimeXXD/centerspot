import SwiftUI

/// Flat or Broadcast in the playback nav bar (mockup `playback--broadcast(-3d)`): two 44 pt icon buttons on a capsule
/// track, the picked one lit in the accent colour. VoiceOver reads "Flat camera" and "Broadcast camera", one selected.
struct CameraSwitch: View {
    @Binding var camera: BoardCamera

    var body: some View {
        HStack(spacing: 0) {
            option(.flat, label: "Flat camera", identifier: "playback.camera.flat") { FlatCameraIcon() }
            option(.broadcast, label: "Broadcast camera", identifier: "playback.camera.broadcast") { BroadcastCameraIcon() }
        }
        .padding(2)
        .background(Tokens.Colour.surface2.color, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera")
    }

    private func option(_ value: BoardCamera, label: String, identifier: String,
                        icon: () -> some Shape) -> some View {
        let on = camera == value
        return Button { camera = value } label: {
            icon()
                .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 22, height: 22)
                .foregroundStyle(on ? Tokens.Colour.text.color : Tokens.Colour.muted.color)
                .frame(width: Tokens.Size.touch, height: Tokens.Size.touch)
                .background(on ? Tokens.Colour.surface3.color : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The mockup's `camFlat` (24-unit box): the pitch from above, a tall rectangle with its halfway line.
struct FlatCameraIcon: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let u = rect.width / 24
        var path = SwiftUI.Path(roundedRect: CGRect(x: rect.minX + 6 * u, y: rect.minY + 3 * u, width: 12 * u, height: 18 * u),
                                cornerRadius: 1.5 * u)
        path.move(to: CGPoint(x: rect.minX + 6 * u, y: rect.minY + 12 * u))
        path.addLine(to: CGPoint(x: rect.minX + 18 * u, y: rect.minY + 12 * u))
        return path
    }
}

/// The mockup's `camBc`: the pitch tilted away, a trapezoid with its halfway line.
struct BroadcastCameraIcon: Shape {
    func path(in rect: CGRect) -> SwiftUI.Path {
        let u = rect.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * u, y: rect.minY + y * u) }
        var path = SwiftUI.Path()
        path.addLines([p(8, 5), p(16, 5), p(21, 19), p(3, 19)])
        path.closeSubpath()
        path.move(to: p(5.2, 12.5))
        path.addLine(to: p(18.8, 12.5))
        return path
    }
}
