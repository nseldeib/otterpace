import SwiftUI

// Circular progress ring toward the daily step goal, with the count and a
// "to go" / "goal hit" caption in the center.
struct StepRing: View {
    let progress: Double
    let steps: Int
    let goal: Int
    let remaining: Int
    let reached: Bool
    var exceeded: Bool = false

    // Ring diameter tracks the user's text size so the centered count never
    // overflows the circle at large Dynamic Type sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var diameter: CGFloat = 150

    // Honor the system "Reduce Motion" setting: snap to the final value instead
    // of sweeping the arc when it's on.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Drives both the trimmed arc length and the gradient span so color and
    // length always move together. Starts empty and sweeps up to `progress`.
    @State private var animatedProgress: Double = 0

    // Clamp the animated value to the drawable arc range (see `stepRingFill`).
    // The caption still reflects the `exceeded` state via the helpers below.
    private var fill: Double { stepRingFill(animatedProgress) }

    // Presentation logic lives in pure, unit-tested helpers (Formatters.swift).
    private var caption: String {
        stepGoalCaption(reached: reached, exceeded: exceeded, goal: goal)
    }

    private var accessibilityValue: String {
        stepGoalAccessibilityValue(steps: steps, goal: goal, remaining: remaining,
                                   reached: reached, exceeded: exceeded)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.brand.opacity(0.14), lineWidth: 14)
            Circle()
                .trim(from: 0, to: fill)
                // Map the gradient onto the FILLED arc (0 → 360°·fill in the
                // shape's local space) instead of wrapping the whole circle, so
                // coral→gold→green flows along the progress and the green
                // leading cap meets the coral start cleanly — no seam at the top.
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.brand, Palette.gold, Palette.go]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * fill)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(formatted(steps))
                    .font(Typography.title2)
                    .foregroundColor(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(caption)
                    .font(Typography.caption)
                    .foregroundColor(Palette.subtle)
                    .multilineTextAlignment(.center)
                if !reached {
                    Text("\(formatted(remaining)) to go")
                        .font(Typography.caption)
                        .foregroundColor(Palette.brand)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily step goal")
        .accessibilityValue(accessibilityValue)
        .onAppear { animate(to: progress) }
        .onChange(of: progress) { newValue in animate(to: newValue) }
    }

    // Sweep the arc to `target` with a gentle ease-out, or snap when Reduce
    // Motion is on. Driving a single state value keeps the gradient span and
    // the trim length in lockstep.
    private func animate(to target: Double) {
        if reduceMotion {
            animatedProgress = target
        } else {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = target
            }
        }
    }
}
