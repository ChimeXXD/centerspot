import CoreGraphics
import Testing
@testable import CenterSpot

/// D-89 (supersedes D-74's grid): tall cards two a row on a phone; from 744 pt a 280 pt sidebar and as many cards of at
/// least 176 pt as fit (mockup `library-v2--phone` and `library-v2--ipad`).
struct LibraryGridTests {
    /// Every iPhone width iOS 26 runs on gets two tall cards a row with 16 pt margins.
    @Test(arguments: [CGFloat(375), 393, 402, 430, 440])
    func phonesShowTwoARow(width: CGFloat) {
        let grid = LibraryGrid(width: width)
        #expect(grid.columns == 2)
        #expect(grid.style == .compact)
        #expect(grid.margin == 16)
        #expect(abs(grid.cardWidth - (width - 32 - 12) / 2) < 0.01, "\(grid.cardWidth)")
    }

    /// The mockup's iPad landscape (13-inch, 1376 pt): the sidebar, then 5 a row at 193.6 pt.
    @Test func theThirteenInchIPadInLandscapeShowsFive() {
        let grid = LibraryGrid(width: 1376)
        #expect(grid.style == .wide)
        #expect(grid.margin == 32)
        #expect(grid.columns == 5)
        #expect(abs(grid.cardWidth - 193.6) < 0.01, "\(grid.cardWidth)")
    }

    /// Other iPad widths: the sidebar always, cards never narrower than 176 pt.
    @Test(arguments: [(CGFloat(1210), 4), (1032, 3), (834, 2), (1366, 5), (1024, 3), (768, 2), (744, 2)])
    func iPadsFitWhatTheyCan(width: CGFloat, columns: Int) {
        let grid = LibraryGrid(width: width)
        #expect(grid.style == .wide)
        #expect(grid.columns == columns, "\(width) pt: \(grid.columns)")
        #expect(grid.cardWidth >= LibraryGrid.minimumWideCard, "\(width) pt: \(grid.cardWidth)")
    }

    /// Split View's narrow windows get the phone's layout.
    @Test(arguments: [CGFloat(320), 507, 678, 743])
    func narrowWindowsUseThePhoneLayout(width: CGFloat) {
        let grid = LibraryGrid(width: width)
        #expect(grid.style == .compact)
        #expect(grid.columns == 2)
    }

    /// At the accessibility text sizes half as many columns: one on a phone.
    @Test func accessibilityTextSizesUseFewerColumns() {
        #expect(LibraryGrid(width: 393, accessibilityText: true).columns == 1)
        #expect(LibraryGrid(width: 1376, accessibilityText: true).columns == 2)
    }

    /// Never more than 6 a row, however wide.
    @Test func neverMoreThanSix() {
        #expect(LibraryGrid(width: 2560).columns == 6)
    }
}
