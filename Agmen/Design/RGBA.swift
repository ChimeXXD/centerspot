import CoreGraphics
import SwiftUI

/// An sRGB colour that both SwiftUI and the Core Graphics renderer (D-07) can use, and tests can measure.
struct RGBA: Sendable, Hashable, CustomStringConvertible {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    private init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// This colour composited over an opaque background, as it appears on screen.
    func over(_ background: RGBA) -> RGBA {
        RGBA(red: red * alpha + background.red * (1 - alpha),
             green: green * alpha + background.green * (1 - alpha),
             blue: blue * alpha + background.blue * (1 - alpha),
             alpha: 1)
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    var description: String {
        String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
