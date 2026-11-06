import Foundation

/// WCAG 2.2 contrast ratio between two opaque sRGB colours (1…21).
enum Contrast {
    /// Composite translucent colours first with `RGBA.over(_:)`; alpha is not part of the formula.
    static func ratio(_ a: RGBA, _ b: RGBA) -> Double {
        assert(a.alpha == 1 && b.alpha == 1, "Contrast.ratio needs opaque colours; composite with over(_:) first")
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Relative luminance, https://www.w3.org/TR/WCAG22/#dfn-relative-luminance
    static func luminance(_ c: RGBA) -> Double {
        func channel(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.red) + 0.7152 * channel(c.green) + 0.0722 * channel(c.blue)
    }
}
