import SwiftUI

/// The app's main entry point: a cinematic command-center title screen with
/// a live animated preview of the system map running behind the copy, so
/// the first few seconds already look like a real game rather than a menu.
struct BreachStartView: View {
    @State private var isPlaying = false
    @State private var quickActions = QuickActionCenter.shared

    var body: some View {
        ZStack {
            CinematicBackgroundView()

            VStack(spacing: 24) {
                Spacer(minLength: 20)

                VStack(spacing: 10) {
                    Text("MIDNIGHT BREACH")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .cyan.opacity(0.55), radius: 14)

                    Text("Try thinking like a cyber defender under pressure.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                MiniNetworkPreview()
                    .frame(height: 170)
                    .padding(.horizontal, 36)

                Spacer(minLength: 20)

                VStack(spacing: 14) {
                    Button {
                        isPlaying = true
                    } label: {
                        Text("Enter System")
                            .font(.headline)
                            .frame(maxWidth: 360)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    ShareLink(item: BreachShareContent.inviteMessage) {
                        Label("Invite a Friend", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 20)
        }
        .fullScreenCover(isPresented: $isPlaying) {
            MidnightBreachFlowView {
                isPlaying = false
            }
        }
        .onAppear { presentIfQuickActionPending() }
        .onChange(of: quickActions.pendingAction) { _, _ in presentIfQuickActionPending() }
    }

    private func presentIfQuickActionPending() {
        guard quickActions.pendingAction == .enterSystem, !isPlaying else { return }
        quickActions.pendingAction = nil
        isPlaying = true
    }
}

/// A small, always-animating teaser of the real system map: five nodes
/// around a glowing core with pulses already traveling inward. Purely
/// decorative — no taps, no game state.
private struct MiniNetworkPreview: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.42

                for i in 0..<5 {
                    let angle = (Double(i) / 5) * 2 * .pi - .pi / 2
                    let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))

                    var line = Path()
                    line.move(to: point)
                    line.addLine(to: center)
                    context.stroke(line, with: .color(.white.opacity(0.16)), lineWidth: 1.5)

                    let pulseT = (t * 0.35 + Double(i) * 0.2).truncatingRemainder(dividingBy: 1)
                    let pulsePoint = CGPoint(
                        x: point.x + (center.x - point.x) * pulseT,
                        y: point.y + (center.y - point.y) * pulseT
                    )
                    context.fill(
                        Path(ellipseIn: CGRect(x: pulsePoint.x - 4, y: pulsePoint.y - 4, width: 8, height: 8)),
                        with: .color(.red.opacity(0.85))
                    )

                    context.fill(
                        Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)),
                        with: .color(.cyan)
                    )
                }

                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)),
                    with: .radialGradient(Gradient(colors: [.cyan, .clear]), center: center, startRadius: 0, endRadius: 28)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Breach Start — iPhone") {
    BreachStartView()
        .preferredColorScheme(.dark)
}

#Preview("Breach Start — iPad") {
    BreachStartView()
        .preferredColorScheme(.dark)
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
