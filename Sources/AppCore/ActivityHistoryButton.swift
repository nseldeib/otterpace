import SwiftUI

// The Today dashboard's entry point into Activity History: a full-width card
// button that opens the recent-workouts history.
struct ActivityHistoryButton: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.day.timeline.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Palette.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity history")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(Palette.ink)
                    Text("Recent workouts & weekly load")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Palette.subtle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Palette.subtle)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open activity history")
    }
}
