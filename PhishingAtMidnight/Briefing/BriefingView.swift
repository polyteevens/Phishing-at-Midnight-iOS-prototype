import SwiftUI

/// Short, letterboxed cinematic intro: supervisor message, the stakes, the
/// objective. Carried by styled text and stillness, no video. ~10-15s on
/// first view; skippable on every view after that.
struct BriefingView: View {
    let onContinue: () -> Void

    @AppStorage("hasSeenBriefing") private var hasSeenBriefing = false
    @State private var visibleLineCount = 0
    @State private var hasFinished = false

    private let lines = [
        "INCOMING TRANSMISSION — NIGHT SHIFT, IT SECURITY DESK",
        "SUPERVISOR MORALES",
        "New analyst. Good, we need one. Patient records are on the line tonight — every email that reaches staff is a live decision.",
        "Quarantine what's dangerous. Let the real ones through. Get it wrong in either direction and people get hurt.",
        NarrativeContent.briefingPatientLine,
        "OBJECTIVE: Clear the queue before your Breach or Disruption meter maxes out.",
    ]

    private let patientLineIndex = 4

    private var skipAvailable: Bool { hasSeenBriefing }

    var body: some View {
        VStack(spacing: 0) {
            Color.black.frame(height: 56)

            ZStack(alignment: .topTrailing) {
                Color(red: 0.035, green: 0.04, blue: 0.055)

                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 0)
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        if index < visibleLineCount {
                            if index == patientLineIndex {
                                HStack(alignment: .top, spacing: 14) {
                                    PatientPortraitView(isSafe: true)
                                    Text(line)
                                        .font(font(for: index))
                                        .foregroundStyle(color(for: index))
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                            } else {
                                Text(line)
                                    .font(font(for: index))
                                    .foregroundStyle(color(for: index))
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

                if skipAvailable {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            Color.black.frame(height: 56)
        }
        .ignoresSafeArea()
        .background(Color.black)
        .task { await playSequence() }
    }

    private func font(for index: Int) -> Font {
        index < 2 ? .caption.weight(.semibold) : .title3.weight(.medium)
    }

    private func color(for index: Int) -> Color {
        index < 2 ? .secondary : .white
    }

    private func playSequence() async {
        let delaysBetweenLines: [Double] = [0.4, 0.6, 1.0, 1.6, 1.7, 1.5]
        for delay in delaysBetweenLines {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) { visibleLineCount += 1 }
        }
        try? await Task.sleep(for: .seconds(1.2))
        guard !Task.isCancelled else { return }
        finish()
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        hasSeenBriefing = true
        onContinue()
    }
}

#Preview("Briefing") {
    BriefingView(onContinue: {})
        .preferredColorScheme(.dark)
}
