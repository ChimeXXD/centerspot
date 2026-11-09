import Foundation

/// The library's words for a move (D-89): its length as a clip ("0:08"), its steps ("5 steps") and when it was last
/// edited ("Today", "Yesterday", "Sat", "2 Nov").
enum LibraryFormat {
    /// How long the move plays, holds included: what Play shows and what the video runs (`Timeline`).
    static func length(of tactic: Tactic) -> Double {
        tactic.phases.first.map(Timeline.duration(of:)) ?? 0
    }

    /// "0:08", "1:05": minutes and seconds, as on a video.
    static func clock(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return "\(whole / 60):" + (whole % 60 < 10 ? "0" : "") + "\(whole % 60)"
    }

    /// Whether a move this long has anything to play: a one-step move rests, so it shows no length.
    static func plays(_ seconds: Double) -> Bool {
        seconds >= 0.5
    }

    /// "1 second", "8 seconds", for VoiceOver.
    static func spokenLength(_ seconds: Double) -> String {
        let whole = max(1, Int(seconds.rounded()))
        return whole == 1 ? "1 second" : "\(whole) seconds"
    }

    /// "1 step", "5 steps" (the main phase, as on the board).
    static func steps(_ tactic: Tactic) -> String {
        let count = tactic.phases.first?.steps.count ?? 0
        return count == 1 ? "1 step" : "\(count) steps"
    }

    /// "Today", "Yesterday", the weekday within the last week ("Sat"), the day and month this year ("2 Nov"), or
    /// with the year before that ("2 Nov 2025").
    static func edited(_ date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if LibraryQuery.isThisWeek(date, now: now, calendar: calendar), date <= now {
            style = style.weekday(.abbreviated)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            style = style.day().month(.abbreviated)
        } else {
            style = style.day().month(.abbreviated).year()
        }
        return date.formatted(style)
    }

    /// `edited` inside a sentence ("Edited today", "edited Sat"): "Today" and "Yesterday" lose their capital, weekday
    /// and month names keep theirs.
    static func editedInSentence(_ date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let word = edited(date, now: now, calendar: calendar, locale: locale)
        return word == "Today" || word == "Yesterday" ? word.lowercased() : word
    }
}
