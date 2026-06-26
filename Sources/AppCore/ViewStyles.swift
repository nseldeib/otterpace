import SwiftUI

// Shared chrome + layout modifiers used across the app's screens and cards.
// These keep the polish DRY: spacing, card chrome, the section labels, and the
// overlay motion all come from one place so every surface reads as one family.

extension View {
    /// The standard white card chrome used by the dashboard's section components:
    /// rounded fill, hairline stroke, soft drop shadow. Corner radius is shared
    /// with the cards that paint their own background (see `Layout.cardCorner`).
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
                    .fill(Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCorner, style: .continuous)
                    .stroke(Palette.ink.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: Palette.ink.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// The shared page margins for a top-level scroll surface — horizontal
    /// gutter plus first/last content insets. Applied to the Today dashboard,
    /// Activity History, and Weekly Review so their vertical rhythm matches
    /// exactly instead of each repeating three `.padding` calls with drifting
    /// values.
    func screenScrollContent() -> some View {
        self
            .padding(.horizontal, Layout.screenGutter)
            .padding(.top, Layout.screenTop)
            .padding(.bottom, Layout.screenBottom)
    }

    /// The recurring card section label — the small, bold, muted caption that
    /// tops nearly every card ("Coach Buddy", "This week", "Latest run"). Codifies
    /// the `captionStrong` + `subtle` pairing so the hierarchy never drifts.
    func cardSectionLabel() -> some View {
        self
            .font(Typography.captionStrong)
            .foregroundColor(Palette.subtle)
    }

    /// A full-screen overlay's entrance/exit, honoring Reduce Motion: a gentle
    /// slide-up + fade normally, downgraded to a pure cross-fade when the user
    /// has asked for less motion. Pair with a `withAnimation(Motion.overlay)`
    /// toggle on the presenting button. Launch-seeded overlays set their state's
    /// initial value, so no transition fires on the first frame — captures stay
    /// fully rendered.
    func overlayTransition() -> some View {
        modifier(OverlayTransition())
    }
}

/// Reduce-Motion-aware transition for full-cover overlays. Reads the environment
/// so the same modifier does the right thing on every surface.
struct OverlayTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }
}
