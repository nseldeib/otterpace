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
}
