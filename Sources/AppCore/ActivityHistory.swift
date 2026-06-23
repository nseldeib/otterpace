import Foundation

// MARK: - Activity history grouping
//
// Pure, deterministic logic behind the Activity History screen: take a flat,
// newest-first list of workouts and roll it up into per-week groups with the
// training-load basics (Milestone 4) — weekly mileage, run count, and rest
// days. No SwiftUI, no I/O, so it's straightforward to unit-test. The grouping
// uses a fixed Monday-start, POSIX calendar so the same workouts always produce
// the same weeks regardless of the device locale.

/// One week's worth of workouts plus its rolled-up training-load basics.
public struct WeekGroup: Equatable, Identifiable {
    public var id: String { weekStartISO }
    public var weekStartISO: String      // ISO date of the Monday that starts the week
    public var title: String             // human label, e.g. "Week of Jun 16"
    public var workouts: [LatestWorkout]  // newest-first within the week
    public var totalMiles: Double
    public var runCount: Int
    public var restDays: Int             // 7 minus the number of distinct active days

    public init(weekStartISO: String, title: String, workouts: [LatestWorkout],
                totalMiles: Double, runCount: Int, restDays: Int) {
        self.weekStartISO = weekStartISO
        self.title = title
        self.workouts = workouts
        self.totalMiles = totalMiles
        self.runCount = runCount
        self.restDays = restDays
    }
}

public enum ActivityHistory {
    // A fixed calendar so week boundaries are deterministic and locale-independent.
    private static var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)   // Monday-start, ISO weeks
        c.locale = Locale(identifier: "en_US_POSIX")
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    private static var parser: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }

    /// Group workouts into weeks, newest week first, each week newest-first
    /// inside it, with mileage / run-count / rest-day rollups. Workouts whose
    /// `date` isn't a valid ISO date are dropped (they can't be placed in a week).
    public static func groupByWeek(_ workouts: [LatestWorkout]) -> [WeekGroup] {
        let cal = calendar
        let fmt = parser

        // Bucket by the Monday that starts each workout's week.
        var buckets: [Date: [LatestWorkout]] = [:]
        for w in workouts {
            guard let d = fmt.date(from: w.date),
                  let weekStart = cal.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            buckets[weekStart, default: []].append(w)
        }

        let labeler = DateFormatter()
        labeler.dateFormat = "MMM d"
        labeler.locale = Locale(identifier: "en_US_POSIX")
        labeler.timeZone = TimeZone(identifier: "UTC")

        return buckets.keys.sorted(by: >).map { weekStart in
            let items = buckets[weekStart]!.sorted { ($0.date, $0.distanceMiles) > ($1.date, $1.distanceMiles) }
            let totalMiles = items.reduce(0) { $0 + $1.distanceMiles }
            let runCount = items.filter { $0.type == "run" }.count
            let activeDays = Set(items.map { $0.date }).count
            let restDays = max(0, 7 - activeDays)
            return WeekGroup(
                weekStartISO: fmt.string(from: weekStart),
                title: "Week of \(labeler.string(from: weekStart))",
                workouts: items,
                totalMiles: totalMiles,
                runCount: runCount,
                restDays: restDays
            )
        }
    }
}
