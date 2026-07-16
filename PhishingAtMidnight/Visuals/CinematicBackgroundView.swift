import SwiftUI

/// The game's shared backdrop: black base, two slow-drifting ambient glows
/// (cool mint for calm systems, dim red for danger), a faint terminal-style
/// scanline grid, and a soft vignette. Used behind every screen so the whole
/// game reads as one consistent, high-tech world rather than flat black.
/// Kept deliberately subtle — this sits behind real UI text, so contrast
/// always wins over atmosphere.
struct CinematicBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black

            TimelineView(.animation(paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    let glow1 = CGPoint(
                        x: size.width * (0.22 + 0.05 * sin(t * 0.05)),
                        y: size.height * (0.15 + 0.04 * cos(t * 0.045))
                    )
                    let glow2 = CGPoint(
                        x: size.width * (0.82 + 0.05 * cos(t * 0.04)),
                        y: size.height * (0.85 + 0.04 * sin(t * 0.055))
                    )

                    context.fill(
                        Path(ellipseIn: CGRect(x: glow1.x - 260, y: glow1.y - 260, width: 520, height: 520)),
                        with: .radialGradient(
                            Gradient(colors: [Color.mint.opacity(0.10), .clear]),
                            center: glow1, startRadius: 0, endRadius: 260
                        )
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: glow2.x - 300, y: glow2.y - 300, width: 600, height: 600)),
                        with: .radialGradient(
                            Gradient(colors: [Color.red.opacity(0.07), .clear]),
                            center: glow2, startRadius: 0, endRadius: 300
                        )
                    )
                }
            }

            ScanlineGridView()
                .opacity(0.05)
                .blendMode(.plusLighter)

            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.55)],
                center: .center, startRadius: 260, endRadius: 620
            )
        }
        .ignoresSafeArea()
    }
}

/// A faint, static horizontal-line texture — reads as an old terminal /
/// HUD scan pattern at very low opacity. Drawn once; not animated.
private struct ScanlineGridView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white))
                y += spacing
            }
        }
    }
}

#Preview {
    CinematicBackgroundView()
        .preferredColorScheme(.dark)
}
