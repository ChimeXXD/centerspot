import Foundation

/// Which moves the library shows and in what order (D-89): the iPad sidebar's All moves · This week · Earlier, and
/// the Recent · Name sort on both layouts.
struct LibraryQuery: Equatable {
    enum Filter: String, CaseIterable, Identifiable {
        case all, thisWeek, earlier
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: "All moves"
            case .thisWeek: "This week"
            case .earlier: "Earlier"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case recent, name
        var id: String { rawValue }
        var title: String { self == .recent ? "Recent" : "Name" }
    }

    var filter = Filter.all
    var sort = Sort.recent

    /// The entries this query shows, from the library's newest-first list.
    func apply(to entries: [TacticLibrary.Entry], now: Date = .now, calendar: Calendar = .current) -> [TacticLibrary.Entry] {
        let kept = entries.filter { Self.matches(filter, $0.modified, now: now, calendar: calendar) }
        switch sort {
        case .recent: return kept
        case .name:
            return kept.sorted {
                let order = $0.tactic.title.localizedStandardCompare($1.tactic.title)
                return order == .orderedSame ? $0.modified > $1.modified : order == .orderedAscending
            }
        }
    }

    /// How many entries `filter` keeps, for the sidebar's counts.
    static func count(_ filter: Filter, in entries: [TacticLibrary.Entry], now: Date = .now,
                      calendar: Calendar = .current) -> Int {
        entries.count { matches(filter, $0.modified, now: now, calendar: calendar) }
    }

    /// Edited today or on one of the six days before it.
    static func isThisWeek(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else { return false }
        return date >= start
    }

    private static func matches(_ filter: Filter, _ date: Date, now: Date, calendar: Calendar) -> Bool {
        switch filter {
        case .all: true
        case .thisWeek: isThisWeek(date, now: now, calendar: calendar)
        case .earlier: !isThisWeek(date, now: now, calendar: calendar)
        }
    }
}
