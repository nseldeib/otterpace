import SwiftUI

// One labeled prose section in the Weekly Review — a tinted icon, an uppercase
// title, and the recap copy on a standard card. Reused for "what went well",
// "what changed", "suggested next week", and the empty-state sections.
struct WeeklyReviewSection: View {
    let icon: String
    let tint: Color
    let title: String
    let body_: String

    init(icon: String, tint: Color, title: String, body: String) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.body_ = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(tint)
                Text(title.uppercased())
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
        .cardStyle()
    }
}
