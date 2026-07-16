import SwiftUI

/// Temporary placeholder Start screen. Per the build brief this is intentionally
/// bare — no real onboarding. Presents TriageView directly for now; BriefingView
/// will be inserted between Start and Triage once it exists.
struct StartView: View {
    @State private var pool: [Specimen] = []
    @State private var loadError: String?
    @State private var isPlaying = false

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

                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    isPlaying = true
                } label: {
                    Text("Begin Shift")
                        .font(.headline)
                        .frame(maxWidth: 360)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(pool.isEmpty)
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 24)
        }
        .task {
            do {
                pool = try SpecimenLoader.loadPool()
            } catch {
                loadError = "Couldn't load the specimen pool: \(error.localizedDescription)"
            }
        }
        .fullScreenCover(isPresented: $isPlaying) {
            TriageView(pool: pool, replayCount: 0) { _ in
                isPlaying = false
            }
        }
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
