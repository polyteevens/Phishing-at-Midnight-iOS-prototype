import SwiftUI

/// Temporary placeholder Start screen. Per the build brief this is intentionally
/// bare — no real onboarding. It will grow a NavigationStack destination into
/// BriefingView once that screen exists.
struct StartView: View {
    @State private var missionComingSoon = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("BECOME")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(.secondary)

                    Text("Phishing at Midnight")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }

                Text("Cyber Defender Academy — Night Shift")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    missionComingSoon = true
                } label: {
                    Text("Begin Shift")
                        .font(.headline)
                        .frame(maxWidth: 360)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 24)

            if missionComingSoon {
                VStack(spacing: 12) {
                    Text("Mission scaffold in progress")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Briefing → Triage → Results are being wired up next.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .onTapGesture { missionComingSoon = false }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: missionComingSoon)
    }
}

#Preview("Start — iPhone") {
    StartView()
        .preferredColorScheme(.dark)
}

#Preview("Start — iPad") {
    StartView()
        .preferredColorScheme(.dark)
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
