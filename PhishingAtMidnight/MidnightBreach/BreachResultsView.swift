import SwiftUI

/// The mission's cinematic payoff, not a report card: a sequenced reveal —
/// headline, grade, Cyber Fit Signal, the skills this run actually tested —
/// building toward Replay.
struct BreachResultsView: View {
    let result: SystemMapEngine.RunResult
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var haptics = HapticsAudioService()
    @State private var stage = 0

    private var isFailure: Bool {
        result.outcome == .breached || result.outcome == .destabilized
    }

    private var headline: String {
        switch result.outcome {
        case .breached: "Core Breached"
        case .destabilized: "System Destabilized"
        case .timeUp: "Shift Contained"
        case .cleared: "System Secured"
        }
    }

    private var subtitle: String {
        switch result.outcome {
        case .breached: "An attack pulse reached the core one too many times."
        case .destabilized: "Too many bad calls under pressure — the system couldn't hold."
        case .timeUp: "You held the line for the whole shift."
        case .cleared: "Every threat got contained before it mattered."
        }
    }

    private var gradeTint: Color {
        switch result.grade {
        case .s: .cyan
        case .a: .green
        case .b: .orange
        case .failed: .red
        }
    }

    var body: some View {
        ZStack {
            CinematicBackgroundView()

            ScrollView {
                VStack(spacing: 22) {
                    Color.clear.frame(height: 28)

                    if stage >= 1 {
                        VStack(spacing: 8) {
                            Text(headline)
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(isFailure ? .red : .white)
                                .multilineTextAlignment(.center)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if stage >= 2 {
                        VStack(spacing: 6) {
                            Image(systemName: result.grade == .failed ? "xmark.seal.fill" : "rosette")
                                .font(.system(size: 40))
                                .foregroundStyle(gradeTint)
                            Text(result.grade == .failed ? "No Grade" : result.grade.rawValue)
                                .font(.title.weight(.heavy))
                                .foregroundStyle(gradeTint)
                        }
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }

                    if stage >= 3 {
                        VStack(spacing: 4) {
                            Text("CYBER FIT SIGNAL")
                                .font(.caption2.weight(.heavy))
                                .tracking(1.2)
                                .foregroundStyle(.tertiary)
                            Text(result.signal.rawValue)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .transition(.opacity)
                    }

                    if stage >= 4 {
                        statCard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if stage >= 5 {
                        VStack(spacing: 12) {
                            Button(action: onReplay) {
                                Text("Replay")
                                    .font(.headline)
                                    .frame(maxWidth: 360)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            Button("Back to Start", action: onExit)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
        }
        .task { await playReveal() }
    }

    private var statCard: some View {
        VStack(spacing: 12) {
            Text("Skills tested")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(["Pattern Recognition", "Prioritization", "Risk Judgment"], id: \.self) { skill in
                    Text(skill)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            Divider().overlay(Color.white.opacity(0.1)).padding(.top, 4)

            HStack {
                statColumn(label: "BREACH", value: "\(Int(result.finalBreach))", tint: .red)
                statColumn(label: "STABILITY", value: "\(Int(result.finalStability))", tint: .cyan)
                statColumn(label: "CONTAINED", value: "\(result.threatsResolved)", tint: .green)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statColumn(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.tertiary)
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }

    private func playReveal() async {
        let delays: [Double] = [0.5, 0.55, 0.45, 0.45, 0.4]
        for (index, delay) in delays.enumerated() {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                stage = index + 1
            }
            if index + 1 == 2 {
                haptics.playImpactBeat(isPositive: result.grade != .failed)
            }
        }
    }
}

#Preview("Breach Results — S") {
    BreachResultsView(
        result: .init(
            outcome: .cleared, grade: .s, signal: .strong,
            finalBreach: 10, finalStability: 92,
            threatsResolved: 8, threatsFailed: 1, totalMistakes: 2
        ),
        onReplay: {}, onExit: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Breach Results — Failed") {
    BreachResultsView(
        result: .init(
            outcome: .breached, grade: .failed, signal: .unclear,
            finalBreach: 100, finalStability: 40,
            threatsResolved: 2, threatsFailed: 5, totalMistakes: 9
        ),
        onReplay: {}, onExit: {}
    )
    .preferredColorScheme(.dark)
}
