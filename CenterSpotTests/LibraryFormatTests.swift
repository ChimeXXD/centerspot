import Foundation
import Testing
@testable import CenterSpot

/// D-89: the library's length, steps and date words, and the sidebar's filters and the sort.
struct LibraryFormatTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Lagos")!
        return calendar
    }()
    private let locale = Locale(identifier: "en_GB")
    /// Monday 9 November 2026, 01:12 in Lagos.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 1, minute: 12))! }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let start = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: hour, to: start)!
    }

    @Test func clockReadsLikeAVideo() {
        #expect(LibraryFormat.clock(0) == "0:00")
        #expect(LibraryFormat.clock(7.6) == "0:08")
        #expect(LibraryFormat.clock(65) == "1:05")
        #expect(LibraryFormat.spokenLength(0.4) == "1 second")
        #expect(LibraryFormat.spokenLength(8.2) == "8 seconds")
        // A one-step move rests: no "0:00" on its card.
        #expect(!LibraryFormat.plays(0))
        #expect(LibraryFormat.plays(1.2))
    }

    @Test func lengthIsWhatPlayRuns() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let phase = try #require(hero.phases.first)
        #expect(LibraryFormat.length(of: hero) == Timeline.duration(of: phase))
        #expect(LibraryFormat.steps(hero) == "5 steps")
    }

    @Test func editedNamesTheDayPlainly() {
        let say = { (date: Date) in LibraryFormat.edited(date, now: now, calendar: calendar, locale: locale) }
        #expect(say(day(0, hour: 0)) == "Today")
        #expect(say(day(-1, hour: 23)) == "Yesterday")
        #expect(say(day(-2)) == "Sat")
        #expect(say(day(-6)) == "Tue")
        #expect(say(day(-7)) == "2 Nov")
        #expect(say(calendar.date(from: DateComponents(year: 2025, month: 12, day: 30, hour: 9))!) == "30 Dec 2025")
        // Inside a sentence ("edited today") only Today and Yesterday lose their capital.
        let inSentence = { (date: Date) in LibraryFormat.editedInSentence(date, now: now, calendar: calendar, locale: locale) }
        #expect(inSentence(day(0)) == "today")
        #expect(inSentence(day(-1)) == "yesterday")
        #expect(inSentence(day(-2)) == "Sat")
    }

    @Test func filtersSplitTheWeekFromEarlier() throws {
        let hero = try Fixtures.tactic("overlap-left")
        let entries = [0, -3, -6, -7, -40].enumerated().map { index, offset in
            TacticLibrary.Entry(url: URL(fileURLWithPath: "/m\(index).tactic"), tactic: hero, modified: day(offset))
        }
        #expect(LibraryQuery.count(.all, in: entries, now: now, calendar: calendar) == 5)
        #expect(LibraryQuery.count(.thisWeek, in: entries, now: now, calendar: calendar) == 3)
        #expect(LibraryQuery.count(.earlier, in: entries, now: now, calendar: calendar) == 2)
        let earlier = LibraryQuery(filter: .earlier).apply(to: entries, now: now, calendar: calendar)
        #expect(earlier.map(\.url.lastPathComponent) == ["m3.tactic", "m4.tactic"])
    }

    @Test func nameSortIsAlphabeticalNewestFirstOnTies() throws {
        let hero = try Fixtures.tactic("overlap-left")
        func entry(_ title: String, _ offset: Int) -> TacticLibrary.Entry {
            var tactic = hero
            tactic.title = title
            return TacticLibrary.Entry(url: URL(fileURLWithPath: "/\(title)\(offset).tactic"), tactic: tactic, modified: day(offset))
        }
        let entries = [entry("press 2", 0), entry("Press 10", -1), entry("Back three", -2), entry("press 2", -3)]
        let byName = LibraryQuery(sort: .name).apply(to: entries, now: now, calendar: calendar)
        #expect(byName.map(\.tactic.title) == ["Back three", "press 2", "press 2", "Press 10"])
        #expect(byName[1].modified > byName[2].modified)
        #expect(LibraryQuery().apply(to: entries, now: now, calendar: calendar) == entries)
    }
}
