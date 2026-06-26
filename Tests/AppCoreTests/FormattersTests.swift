import XCTest
@testable import AppCore

// XCTest (not swift-testing) so results land in the editor's --xunit-output file.
final class FormattersTests: XCTestCase {

    // formatted groups thousands with separators for readable step counts.
    func testFormattedGroupsThousands() {
        XCTAssertEqual(formatted(11240), "11,240")
        XCTAssertEqual(formatted(10000), "10,000")
        XCTAssertEqual(formatted(1234567), "1,234,567")
    }

    // formatted leaves small numbers and zero untouched.
    func testFormattedSmallNumbers() {
        XCTAssertEqual(formatted(0), "0")
        XCTAssertEqual(formatted(42), "42")
        XCTAssertEqual(formatted(999), "999")
    }

    // movementLabel reads "now" at or below zero minutes since moving.
    func testMovementLabelNow() {
        XCTAssertEqual(movementLabel(0), "now")
        XCTAssertEqual(movementLabel(-5), "now")
    }

    // movementLabel uses bare minutes under an hour.
    func testMovementLabelMinutes() {
        XCTAssertEqual(movementLabel(1), "1m")
        XCTAssertEqual(movementLabel(45), "45m")
        XCTAssertEqual(movementLabel(59), "59m")
    }

    // movementLabel rolls into hours, dropping the minutes part when it is zero.
    func testMovementLabelHours() {
        XCTAssertEqual(movementLabel(60), "1h")
        XCTAssertEqual(movementLabel(92), "1h32m")
        XCTAssertEqual(movementLabel(125), "2h5m")
    }

    // prettyDate turns a valid ISO date into a short weekday-and-day label.
    func testPrettyDateValid() {
        XCTAssertEqual(prettyDate("2026-06-22"), "Mon, Jun 22")
        XCTAssertEqual(prettyDate("2026-01-01"), "Thu, Jan 1")
    }

    // prettyDate returns the input unchanged when it is not a valid ISO date.
    func testPrettyDateInvalidFallsThrough() {
        XCTAssertEqual(prettyDate(""), "")
        XCTAssertEqual(prettyDate("not-a-date"), "not-a-date")
    }

    // stepGoalCaption frames the goal when it has not been reached yet.
    func testStepGoalCaptionNotReached() {
        XCTAssertEqual(stepGoalCaption(reached: false, exceeded: false, goal: 10000), "of 10,000")
        XCTAssertEqual(stepGoalCaption(reached: false, exceeded: false, goal: 8000), "of 8,000")
    }

    // stepGoalCaption celebrates exactly hitting the goal.
    func testStepGoalCaptionReachedExactly() {
        XCTAssertEqual(stepGoalCaption(reached: true, exceeded: false, goal: 10000), "goal hit! 🎉")
    }

    // stepGoalCaption gives extra cheer once the goal is passed; exceeded wins over reached.
    func testStepGoalCaptionExceeded() {
        XCTAssertEqual(stepGoalCaption(reached: true, exceeded: true, goal: 10000), "Goal crushed! 🎉")
    }

    // stepGoalAccessibilityValue spells out remaining steps when the goal is not yet met.
    func testStepGoalA11yNotReached() {
        XCTAssertEqual(
            stepGoalAccessibilityValue(steps: 6420, goal: 10000, remaining: 3580, reached: false, exceeded: false),
            "6,420 of 10,000 steps. 3,580 to go."
        )
    }

    // stepGoalAccessibilityValue announces the goal as reached at exactly the goal.
    func testStepGoalA11yReachedExactly() {
        XCTAssertEqual(
            stepGoalAccessibilityValue(steps: 10000, goal: 10000, remaining: 0, reached: true, exceeded: false),
            "10,000 steps. Goal of 10,000 reached."
        )
    }

    // stepGoalAccessibilityValue celebrates a crushed goal when steps exceed the goal.
    func testStepGoalA11yExceeded() {
        XCTAssertEqual(
            stepGoalAccessibilityValue(steps: 14200, goal: 10000, remaining: 0, reached: true, exceeded: true),
            "14,200 steps. You crushed your goal of 10,000."
        )
    }

    // stepRingFill passes typical mid-progress fractions through unchanged.
    func testStepRingFillMidProgress() {
        XCTAssertEqual(stepRingFill(0.32), 0.32, accuracy: 1e-9)
        XCTAssertEqual(stepRingFill(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(stepRingFill(0.999), 0.999, accuracy: 1e-9)
    }

    // stepRingFill floors at a tiny positive value so the rounded cap shows at 0%.
    func testStepRingFillFloorsAtZero() {
        XCTAssertEqual(stepRingFill(0), 0.001, accuracy: 1e-9)
        XCTAssertEqual(stepRingFill(-0.4), 0.001, accuracy: 1e-9)
    }

    // stepRingFill clamps a met goal to exactly a full ring.
    func testStepRingFillExactlyFull() {
        XCTAssertEqual(stepRingFill(1.0), 1.0, accuracy: 1e-9)
    }

    // stepRingFill caps a crushed goal (progress > 1) at a full ring, no overdraw.
    func testStepRingFillExceededCapsAtFull() {
        XCTAssertEqual(stepRingFill(1.4), 1.0, accuracy: 1e-9)
        XCTAssertEqual(stepRingFill(3.0), 1.0, accuracy: 1e-9)
    }
}
