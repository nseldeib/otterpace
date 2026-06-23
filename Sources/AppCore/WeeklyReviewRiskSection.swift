import SwiftUI

// The training-risk section. Takes the amber, shield-marked safety treatment
// when the week's load warrants caution (a spiking load) and a calm green
// treatment when risk is low — the same visual language as `CoachCard`'s
// safety-flagged state.
struct WeeklyReviewRiskSection: View {
    let body_: String
    let safetyFlag: Bool

    init(body: String, safetyFlag: Bool) {
        self.body_ = body
        self.safetyFlag = safetyFlag
    }

    private var tint: Color { safetyFlag ? Palette.amber : Palette.go }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: safetyFlag ? "exclamationmark.shield.fill" : "shield.lefthalf.filled")
                    .foregroundColor(tint)
                Text("Training risk")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Palette.subtle)
            }
            Text(body_)
                .font(.system(size: 15))
                .foregroundColor(Palette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}
