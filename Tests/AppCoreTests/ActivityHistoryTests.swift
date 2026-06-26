import XCTest
@testable import AppCore

// XCTest (not swift-testing) so results land in the editor's --xunit-output file.
final class ActivityHistoryTests: XCTestCase {

    private func wk(_ type: String, _ miles: Double, _ date: String, dur: Int = 40, src: String = "healthkit") -> LatestWorkout {
        LatestWorkout(type: type, distanceMiles: miles, durationMinutes: dur, pace: "10:00/mi", date: date, source: src)
    }

    // An empty workout list yields no week groups.
    func testEmptyYieldsNoGroups() {
        XCTAssertTrue(ActivityHistory.groupByWeek([]).isEmpty)
    }

    // Workouts in the same ISO week collapse into one group.
    func testSameWeekGroupsTogether() {
        // 2026-06-16 (Tue) and 2026-06-21 (Sun) are in the same Monday-start week.
        let groups = ActivityHistory.groupByWeek([wk("run", 3.0, "2026-06-16"), wk("walk", 2.0, "2026-06-21")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].workouts.count, 2)
    }

    // Workouts in different weeks produce separate groups, newest week first.
    func testDifferentWeeksNewestFirst() {
        let groups = ActivityHistory.groupByWeek([wk("run", 3.0, "2026-06-09"), wk("run", 4.0, "2026-06-21")])
        XCTAssertEqual(groups.count, 2)
        XCTAssertGreaterThan(groups[0].weekStartISO, groups[1].weekStartISO)
    }

    // Total mileage sums every workout in the week.
    func testTotalMilesSums() {
        let groups = ActivityHistory.groupByWeek([wk("run", 4.2, "2026-06-21"), wk("walk", 2.0, "2026-06-19"), wk("run", 3.5, "2026-06-16")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].totalMiles, 9.7, accuracy: 0.001)
    }

    // Run count includes only run-type workouts, not walks or rides.
    func testRunCountExcludesNonRuns() {
        let groups = ActivityHistory.groupByWeek([wk("run", 4.0, "2026-06-21"), wk("walk", 2.0, "2026-06-20"), wk("ride", 12.0, "2026-06-19")])
        XCTAssertEqual(groups[0].runCount, 1)
    }

    // Rest days are seven minus the number of distinct active days.
    func testRestDaysFromDistinctActiveDays() {
        // Three workouts across two distinct days => 5 rest days.
        let groups = ActivityHistory.groupByWeek([wk("run", 3.0, "2026-06-21"), wk("walk", 1.0, "2026-06-21"), wk("run", 4.0, "2026-06-18")])
        XCTAssertEqual(groups[0].restDays, 5)
    }

    // A full seven distinct active days leaves zero rest days, never negative.
    func testRestDaysNeverNegative() {
        let week = (15...21).map { wk("run", 3.0, "2026-06-\($0)") }  // Mon..Sun
        let groups = ActivityHistory.groupByWeek(week)
        XCTAssertEqual(groups[0].restDays, 0)
    }

    // Workouts with an unparseable date are dropped rather than crashing.
    func testInvalidDateDropped() {
        let groups = ActivityHistory.groupByWeek([wk("run", 3.0, "not-a-date"), wk("run", 4.0, "2026-06-21")])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].workouts.count, 1)
    }

    // Within a week, workouts are ordered newest-first by date.
    func testWithinWeekNewestFirst() {
        let groups = ActivityHistory.groupByWeek([wk("run", 3.0, "2026-06-16"), wk("run", 4.0, "2026-06-21")])
        XCTAssertEqual(groups[0].workouts.first?.date, "2026-06-21")
    }

    // The model decodes a seeded rbWorkoutsJSON list into the today state.
    func testModelDecodesWorkoutsJSON() {
        let suite = "ActivityHistoryTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        d.set(true, forKey: "rbConnected")
        d.set("[{\"type\":\"run\",\"distanceMiles\":4.2,\"durationMinutes\":44,\"pace\":\"10:00/mi\",\"date\":\"2026-06-21\",\"source\":\"strava\"}]", forKey: "rbWorkoutsJSON")
        let state = OtterpaceModel.readState(defaults: d)
        XCTAssertEqual(state.workouts.count, 1)
        XCTAssertEqual(state.workouts.first?.type, "run")
        XCTAssertEqual(state.workouts.first?.distanceMiles ?? 0, 4.2, accuracy: 0.001)
    }

    // With no rbWorkoutsJSON seeded, the workouts list is empty (day-one).
    func testModelEmptyWhenUnseeded() {
        let suite = "ActivityHistoryTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        defer { d.removePersistentDomain(forName: suite) }
        XCTAssertTrue(OtterpaceModel.readState(defaults: d).workouts.isEmpty)
    }

    // MARK: weeklyLoad(from:asOf:) — the live HealthKit/Strava derivation (SW-1)

    // A fixed reference day inside the week of Mon 2026-06-22 (UTC ISO week).
    private static let asOf: Date = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: "2026-06-24")!   // Wednesday
    }()

    // Only the week containing `asOf` feeds the rollup; mileage, longest run,
    // run-days and rest-days come from that week alone.
    func testWeeklyLoadRollsUpCurrentWeek() {
        let load = ActivityHistory.weeklyLoad(from: [
            wk("run", 4.0, "2026-06-22"),   // current week (Mon)
            wk("run", 6.0, "2026-06-24"),   // current week (Wed) — longest
            wk("walk", 2.0, "2026-06-24"),  // same day, not a run
            wk("run", 9.0, "2026-06-15"),   // previous week — excluded from the rollup
        ], asOf: Self.asOf)
        XCTAssertEqual(load.weeklyMileage, 12.0, accuracy: 0.001)  // 4+6+2
        XCTAssertEqual(load.longestRunMiles, 6.0, accuracy: 0.001)
        XCTAssertEqual(load.daysRunThisWeek, 2)                    // Mon + Wed
        XCTAssertEqual(load.restDaysThisWeek, 5)                   // 7 - 2 active days
    }

    // A big jump over the previous week is flagged "spiking" (the safety signal).
    func testWeeklyLoadSpikingTrend() {
        let load = ActivityHistory.weeklyLoad(from: [
            wk("run", 10.0, "2026-06-23"),  // current week
            wk("run", 5.0, "2026-06-16"),   // previous week — 10/5 = 2.0x
        ], asOf: Self.asOf)
        XCTAssertEqual(load.loadTrend, "spiking")
    }

    // Pulling back vs. the previous week reads as "recovering".
    func testWeeklyLoadRecoveringTrend() {
        let load = ActivityHistory.weeklyLoad(from: [
            wk("run", 3.0, "2026-06-23"),   // current week
            wk("run", 10.0, "2026-06-16"),  // previous week — 3/10 = 0.3x
        ], asOf: Self.asOf)
        XCTAssertEqual(load.loadTrend, "recovering")
    }

    // No prior-week mileage with activity this week reads as "building".
    func testWeeklyLoadBuildingFromZeroBase() {
        let load = ActivityHistory.weeklyLoad(from: [wk("run", 4.0, "2026-06-23")], asOf: Self.asOf)
        XCTAssertEqual(load.loadTrend, "building")
    }

    // No workouts at all: an all-rest week, steady, nothing logged.
    func testWeeklyLoadEmptyIsRestWeek() {
        let load = ActivityHistory.weeklyLoad(from: [], asOf: Self.asOf)
        XCTAssertEqual(load.weeklyMileage, 0)
        XCTAssertEqual(load.daysRunThisWeek, 0)
        XCTAssertEqual(load.restDaysThisWeek, 7)
        XCTAssertEqual(load.loadTrend, "steady")
    }
}
