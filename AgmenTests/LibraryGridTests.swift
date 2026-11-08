import CoreGraphics
import Testing
@testable import Agmen

/// D-74: cards a row from the width available (mockup `library--compact` and `ipad-library`).
struct LibraryGridTests {
    /// Every iPhone width iOS 26 runs on gets 3 a row, too small for numbers.
    @Test(arguments: [CGFloat(375), 393, 402, 430, 440])
    func phonesShowThreeARow(width: CGFloat) {
        let grid = LibraryGrid(width: width)
        #expect(grid.columns == 3)
        #expect(grid.style == .compact)
        #expect(grid.margin == 24)
        #expect(!CardStyle.card.showsNumbers(pitchLength: grid.pitchLength), "\(grid.pitchLength) pt pitch")
    }

    /// The mockup's iPhone card: 108.3 pt wide, a 92.3 pt pitch.
    @Test func theMockupsPhoneCard() {
        let grid = LibraryGrid(width: 393)
        #expect(abs(grid.cardWidth - 108.33) < 0.01, "\(grid.cardWidth)")
        #expect(abs(grid.pitchLength - 92.33) < 0.01, "\(grid.pitchLength)")
    }

    /// The mockup's iPad landscape (13-inch, 1376 pt): 6 a row, 205.3 pt cards, a 185.3 pt pitch with numbers.
    @Test func theThirteenInchIPadInLandscapeShowsSix() {
        let grid = LibraryGrid(width: 1376)
        #expect(grid.columns == 6)
        #expect(grid.style == .wide)
        #expect(grid.margin == 32)
        #expect(abs(grid.cardWidth - 205.33) < 0.01, "\(grid.cardWidth)")
        #expect(abs(grid.pitchLength - 185.33) < 0.01, "\(grid.pitchLength)")
        #expect(CardStyle.card.showsNumbers(pitchLength: grid.pitchLength))
    }

    /// Other iPad widths: every wide card is wide enough for numbers.
    @Test(arguments: [(CGFloat(1210), 5), (1032, 4), (834, 3), (1366, 6), (1024, 4), (768, 3)])
    func iPadsFitWhatTheyCan(width: CGFloat, columns: Int) {
        let grid = LibraryGrid(width: width)
        #expect(grid.columns == columns, "\(width) pt: \(grid.columns)")
        #expect(grid.style == .wide)
        #expect(grid.cardWidth >= LibraryGrid.minimumWideCard)
        #expect(CardStyle.card.showsNumbers(pitchLength: grid.pitchLength), "\(width) pt: \(grid.pitchLength) pt pitch")
    }

    /// Split View's narrow windows fall back to the compact cards.
    @Test(arguments: [CGFloat(320), 507, 678])
    func narrowWindowsUseCompactCards(width: CGFloat) {
        let grid = LibraryGrid(width: width)
        #expect(grid.style == .compact)
        #expect(grid.columns >= 2)
        #expect(grid.cardWidth >= LibraryGrid.minimumCompactCard)
    }

    /// At the accessibility text sizes a third as many columns: one on a phone.
    @Test func accessibilityTextSizesUseFewerColumns() {
        #expect(LibraryGrid(width: 393, accessibilityText: true).columns == 1)
        #expect(LibraryGrid(width: 1376, accessibilityText: true).columns == 2)
    }

    /// Never more than 6 a row, however wide.
    @Test func neverMoreThanSix() {
        #expect(LibraryGrid(width: 2560).columns == 6)
    }
}
