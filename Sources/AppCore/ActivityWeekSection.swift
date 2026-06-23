import SwiftUI

// One week in the Activity History: a header row with the week label and its
// training-load rollup (miles · runs · rest days), followed by the week's
// workouts rendered as the shared WorkoutCard rows.
struct ActivityWeekSection: View {
    let group: WeekGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Palette.ink)
                Spacer()
                Text(rollup)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Palette.subtle)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(group.title). \(spokenRollup)")

            ForEach(group.workouts) { WorkoutCard(workout: $0) }
        }
    }

    private var milesText: String {
        group.totalMiles == group.totalMiles.rounded()
            ? "\(Int(group.totalMiles))"
            : String(format: "%.1f", group.totalMiles)
    }

    private var rollup: String {
        "\(milesText) mi · \(group.runCount) \(group.runCount == 1 ? "run" : "runs") · \(group.restDays) rest"
    }

    private var spokenRollup: String {
        "\(milesText) miles, \(group.runCount) \(group.runCount == 1 ? "run" : "runs"), \(group.restDays) rest \(group.restDays == 1 ? "day" : "days")"
    }
}

// LatestWorkout needs an identity to drive the ForEach above. Date + distance +
// source is stable enough to distinguish rows within a week.
extension LatestWorkout: Identifiable {
    public var id: String { "\(date)-\(distanceMiles)-\(source)-\(durationMinutes)" }
}
