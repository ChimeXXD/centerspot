import Testing
import UIKit
@testable import Agmen

/// The Floodlight Chalk tokens meet WCAG 2.2 contrast (D-44, D1-3): numbers and text 4.5:1 (AA), graphics 3:1 (1.4.11).
struct TokenContrastTests {
    @Test(arguments: Side.Colour.allCases)
    func homeNumberIsReadableOnItsFill(colour: Side.Colour) {
        let kit = Tokens.kit(colour)
        #expect(Contrast.ratio(kit.ink, kit.fill) >= 4.5, "\(colour): number ink on fill")
    }

    @Test func awayNumberIsReadableInsideTheRing() {
        // The ring's inside is a dark disc over the pitch; its number is drawn in one ink for every kit.
        for stripe in [Tokens.Colour.pitchA, Tokens.Colour.pitchB] {
            let inside = Tokens.Colour.awayInner.over(stripe)
            #expect(Contrast.ratio(Tokens.Colour.awayInk, inside) >= 4.5, "away ink on \(stripe)")
        }
    }

    @Test(arguments: Side.Colour.allCases)
    func everyDiscAndRingStandsOutFromThePitch(colour: Side.Colour) {
        // A kit too close to the pitch gets a light outline; whichever edge shows must reach 3:1 on both stripes.
        let kit = Tokens.kit(colour), edge = kit.outline ?? kit.fill
        for stripe in [Tokens.Colour.pitchA, Tokens.Colour.pitchB] {
            #expect(Contrast.ratio(edge, stripe) >= 3, "\(colour) on \(stripe)")
        }
    }

    @Test func outlinesOnlyWhereTheFillAloneWouldVanish() {
        for colour in Side.Colour.allCases {
            let kit = Tokens.kit(colour)
            let plain = [Tokens.Colour.pitchA, Tokens.Colour.pitchB].map { Contrast.ratio(kit.fill, $0) }.min()!
            #expect((kit.outline != nil) == (plain < 3), "\(colour): outline \(kit.outline != nil), fill contrast \(plain)")
        }
    }

    @Test func interfaceTextIsReadable() {
        let pairs: [(String, RGBA, RGBA)] = [
            ("text on background", Tokens.Colour.text, Tokens.Colour.bg),
            ("text on surface", Tokens.Colour.text, Tokens.Colour.surface),
            ("text on raised surface", Tokens.Colour.text, Tokens.Colour.surface3),
            ("muted on background", Tokens.Colour.muted, Tokens.Colour.bg),
            ("muted on surface", Tokens.Colour.muted, Tokens.Colour.surface),
            ("muted on surface 2", Tokens.Colour.muted, Tokens.Colour.surface2),
            ("accent ink on accent", Tokens.Colour.accentInk, Tokens.Colour.accent),
            ("danger on surface 2", Tokens.Colour.danger, Tokens.Colour.surface2),
        ]
        for (name, ink, paper) in pairs { #expect(Contrast.ratio(ink, paper) >= 4.5, "\(name)") }
    }

    @Test func contrastMatchesTheWCAGFormula() {
        #expect(abs(Contrast.ratio(RGBA(0xFFFFFF), RGBA(0x000000)) - 21) < 0.01)
        #expect(abs(Contrast.ratio(RGBA(0x777777), RGBA(0xFFFFFF)) - 4.48) < 0.01)
    }

    @Test func floodlightChalkFontsAreRegistered() {
        // Font.custom falls back to the system font silently, so check the exact names Tokens asks for.
        for name in [Tokens.Typeface.uiName, Tokens.Typeface.noteName] {
            #expect(UIFont.familyNames.contains(name))
            #expect(UIFont(name: name, size: 15) != nil, "\(name) does not resolve by name")
        }
    }
}
