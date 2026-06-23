import Foundation

// Pure presentation helpers shared by the Today dashboard components. Kept free
// of SwiftUI so they're straightforward to unit-test.

/// Group a whole number with locale thousands separators, e.g. 11240 -> "11,240".
func formatted(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Compact "time since last movement" label: "now", "45m", "1h", "1h32m".
func movementLabel(_ minutes: Int) -> String {
    if minutes <= 0 { return "now" }
    if minutes < 60 { return "\(minutes)m" }
    let h = minutes / 60, m = minutes % 60
    return m == 0 ? "\(h)h" : "\(h)h\(m)m"
}

/// Caption shown under the step count in the goal ring. Stays warm and
/// celebratory once the goal is met — with extra cheer when it's been passed —
/// and otherwise frames the goal the user is working toward.
func stepGoalCaption(reached: Bool, exceeded: Bool, goal: Int) -> String {
    if exceeded { return "Goal crushed! 🎉" }
    if reached { return "goal hit! 🎉" }
    return "of \(formatted(goal))"
}

/// Spoken VoiceOver summary for the step-goal ring. Never shame-based, always
/// whole numbers; mirrors the three visual states of `stepGoalCaption`.
func stepGoalAccessibilityValue(steps: Int, goal: Int, remaining: Int, reached: Bool, exceeded: Bool) -> String {
    if exceeded { return "\(formatted(steps)) steps. You crushed your goal of \(formatted(goal))." }
    if reached { return "\(formatted(steps)) steps. Goal of \(formatted(goal)) reached." }
    return "\(formatted(steps)) of \(formatted(goal)) steps. \(formatted(remaining)) to go."
}

/// Render an ISO `yyyy-MM-dd` date as "EEE, MMM d" (e.g. "Mon, Jun 22").
/// Falls back to the raw string when it isn't a valid ISO date.
func prettyDate(_ iso: String) -> String {
    let inFmt = DateFormatter()
    inFmt.dateFormat = "yyyy-MM-dd"
    inFmt.locale = Locale(identifier: "en_US_POSIX")
    guard let d = inFmt.date(from: iso) else { return iso }
    let out = DateFormatter()
    out.dateFormat = "EEE, MMM d"
    out.locale = Locale(identifier: "en_US_POSIX")
    return out.string(from: d)
}
