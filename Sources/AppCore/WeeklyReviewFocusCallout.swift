import SwiftUI

// The recap's closing "one focus area" callout — a single, prominent next-action
// on the brand/gold gradient that anchors the whole review on one clear move.
struct WeeklyReviewFocusCallout: View {
    let focus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "target").foregroundColor(Palette.brand)
                Text("One focus area")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Palette.brandDeep)
            }
            Text(focus)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Palette.brand.opacity(0.14), Palette.gold.opacity(0.14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Palette.brand.opacity(0.22), lineWidth: 1)
        )
    }
}
