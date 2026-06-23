import XCTest
@testable import AppCore

// XCTest (not swift-testing) so results land in the editor's --xunit-output file.
final class WeeklyReviewEngineTests: XCTestCase {

    // MARK: Helpers

    private func state(_ load: WeeklyLoad?) -> TodayState {
        var s = TodayState(healthKitConnected: true, steps: 6000, goalSteps: 10000)
        s.weeklyLoad = load
        return s
    }

    private func solidLoad(trend: String = "building") -> WeeklyLoad {
        WeeklyLoad(weeklyMileage: 22, daysRunThisWeek: 4, longestRunMiles: 8,
                   restDaysThisWeek: 2, loadTrend: trend)
    }

    private func spikingLoad() -> WeeklyLoad {
        WeeklyLoad(weeklyMileage: 31, daysRunThisWeek: 5, longestRunMiles: 11,
                   restDaysThisWeek: 0, loadTrend: "spiking")
    }

    private func sparseLoad() -> WeeklyLoad {
        WeeklyLoad(weeklyMileage: 3.5, daysRunThisWeek: 1, longestRunMiles: 3.5,
                   restDaysThisWeek: 5, loadTrend: "recovering")
    }

    // MARK: Empty

    // With no weekly load at all, the review is the encouraging first-week prompt.
    func testNoLoadIsEmptyReview() {
        let r = WeeklyReviewEngine.generate(from: state(nil))
        XCTAssertFalse(r.hasActivity)
        XCTAssertEqual(r.buddyMood, .ready)
        XCTAssertFalse(r.safetyFlag)
        XCTAssertFalse(r.focusArea.isEmpty)
    }

    // A load object with zero mileage and zero runs still counts as no activity.
    func testZeroActivityLoadIsEmptyReview() {
        let load = WeeklyLoad(weeklyMileage: 0, daysRunThisWeek: 0, longestRunMiles: 0,
                              restDaysThisWeek: 0, loadTrend: "")
        let r = WeeklyReviewEngine.generate(from: state(load))
        XCTAssertFalse(r.hasActivity)
    }

    // MARK: Spiking — safety

    // A spiking load is safety-flagged, concerned, and escalates real warning signs.
    func testSpikingIsSafetyFlagged() {
        let r = WeeklyReviewEngine.generate(from: state(spikingLoad()))
        XCTAssertTrue(r.hasActivity)
        XCTAssertTrue(r.safetyFlag)
        XCTAssertEqual(r.buddyMood, .concerned)
        XCTAssertTrue(r.trainingRisk.lowercased().contains("clinician"))
    }

    // Spiking wins even when several runs went in — load trend dominates.
    func testSpikingWinsOverHighRunCount() {
        var load = spikingLoad()
        load.daysRunThisWeek = 6
        let r = WeeklyReviewEngine.generate(from: state(load))
        XCTAssertTrue(r.safetyFlag)
        XCTAssertEqual(r.buddyMood, .concerned)
    }

    // MARK: Solid

    // A building week is celebratory and not safety-flagged.
    func testBuildingWeekIsCheeringAndUnflagged() {
        let r = WeeklyReviewEngine.generate(from: state(solidLoad(trend: "building")))
        XCTAssertTrue(r.hasActivity)
        XCTAssertEqual(r.buddyMood, .cheering)
        XCTAssertFalse(r.safetyFlag)
        XCTAssertFalse(r.wentWell.isEmpty)
        XCTAssertFalse(r.whatChanged.isEmpty)
    }

    // A steady week is also positive and unflagged, with steady-specific framing.
    func testSteadyWeekIsUnflagged() {
        let r = WeeklyReviewEngine.generate(from: state(solidLoad(trend: "steady")))
        XCTAssertEqual(r.buddyMood, .cheering)
        XCTAssertFalse(r.safetyFlag)
        XCTAssertTrue(r.whatChanged.lowercased().contains("steady"))
    }

    // MARK: Sparse

    // A single-run, mostly-rest week reads gently and is never safety-flagged.
    func testSparseWeekIsGentleAndUnflagged() {
        let r = WeeklyReviewEngine.generate(from: state(sparseLoad()))
        XCTAssertTrue(r.hasActivity)
        XCTAssertEqual(r.buddyMood, .ready)
        XCTAssertFalse(r.safetyFlag)
    }

    // A zero-run week that still logged mileage is treated as sparse, not empty.
    func testZeroRunsWithMileageIsSparse() {
        let load = WeeklyLoad(weeklyMileage: 2.0, daysRunThisWeek: 0, longestRunMiles: 0,
                              restDaysThisWeek: 6, loadTrend: "recovering")
        let r = WeeklyReviewEngine.generate(from: state(load))
        XCTAssertTrue(r.hasActivity)
        XCTAssertFalse(r.safetyFlag)
    }

    // MARK: Determinism

    // The same context always yields an identical review.
    func testDeterministic() {
        let s = state(spikingLoad())
        XCTAssertEqual(WeeklyReviewEngine.generate(from: s), WeeklyReviewEngine.generate(from: s))
    }

    // Every activity review fills all five sections plus a focus area.
    func testActivityReviewsFillAllSections() {
        for load in [solidLoad(), spikingLoad(), sparseLoad()] {
            let r = WeeklyReviewEngine.generate(from: state(load))
            XCTAssertFalse(r.headline.isEmpty)
            XCTAssertFalse(r.wentWell.isEmpty)
            XCTAssertFalse(r.whatChanged.isEmpty)
            XCTAssertFalse(r.trainingRisk.isEmpty)
            XCTAssertFalse(r.nextWeek.isEmpty)
            XCTAssertFalse(r.focusArea.isEmpty)
        }
    }
}
