import SwiftUI

/// Episode-style results screen, built as the run's emotional climax: a beat
/// of suspense, then the grade reveals with weight, the human stakes land,
/// Supervisor Morales reacts, the stats count up, and a new record (if any)
/// gets its own moment — all building toward the one obvious next move.
struct ResultsView: View {
    struct BestStats: Equatable {
        let grade: TriageEngine.Grade
        let accuracy: Double
        let bestCombo: Int
    }

    let result: TriageEngine.RunResult
    let best: BestStats?
    let isNewBestCombo: Bool
    let isNewBestAccuracy: Bool
    let onReplay: () -> Void
    let onExit: () -> Void

    @State private var haptics = HapticsAudioService()
    @State private var stage = 0

    @State private var revealedAccuracy: Double = 0
    @State private var revealedSpeedBonus: Double = 0
    @State private var revealedBreach: Double = 0
    @State private var revealedDisruption: Double = 0

    private var isFailure: Bool {
        result.outcome == .breached || result.outcome == .disrupted
    }

    private var isNewRecord: Bool { isNewBestCombo || isNewBestAccuracy }

    private var headline: String {
        switch result.outcome {
        case .breached: "Systems Compromised"
        case .disrupted: "Operations Disrupted"
        case .timeUp: "Shift Over"
        case .cleared: "Inbox Cleared"
        }
    }

    private var subtitle: String {
        switch result.outcome {
        case .breached: "A dangerous email reached staff and was clicked one too many times."
        case .disrupted: "Too many legitimate emails got blocked — the hospital felt it."
        case .timeUp: "The night shift ended before you cleared the queue."
        case .cleared: "Queue cleared with time to spare."
        }
    }

    private var skillUnlockedLine: String {
        switch result.grade {
        case .gold: "Skill unlocked: Nerve of Steel"
        case .silver: "Skill unlocked: Steady Hands"
        case .bronze: "Skill unlocked: Quick Reflexes"
        case .failed: "Skill unlocked: Lessons from the Wreckage"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Color.clear.frame(height: 28)

                if stage >= 1 {
                    headlineBlock
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if stage >= 2 {
                    GradeBadgeView(grade: result.grade)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }

                if stage >= 3 {
                    patientBlock
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                if stage >= 4 {
                    Text(NarrativeContent.moralesReaction(for: result))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }

                if stage >= 5 {
                    VStack(spacing: 10) {
                        statGrid
                        if isNewRecord {
                            newRecordBadge
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else if let best {
                            Text("Best: \(best.grade.rawValue) · \(Int(best.accuracy.rounded()))% · ×\(best.bestCombo) combo")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Text(skillUnlockedLine)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if stage >= 6 {
                    actionButtons
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .background { CinematicBackgroundView() }
        .task { await playReveal() }
    }

    // MARK: - Reveal sequence

    private func playReveal() async {
        let stepDelays: [Double] = [0.55, 0.55, 0.5, 0.5, 0.4, 0.5]
        for (index, delay) in stepDelays.enumerated() {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            let newStage = index + 1
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                stage = newStage
            }
            if newStage == 2 {
                haptics.playResultsSting(grade: result.grade)
            }
            if newStage == 5 {
                withAnimation(.easeOut(duration: 0.9)) {
                    revealedAccuracy = result.accuracy
                    revealedSpeedBonus = result.speedBonus
                    revealedBreach = result.finalBreach
                    revealedDisruption = result.finalDisruption
                }
            }
        }
    }

    // MARK: - Blocks

    private var headlineBlock: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(isFailure ? .red : .white)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var patientBlock: some View {
        VStack(spacing: 10) {
            PatientPortraitView(isSafe: NarrativeContent.patientIsSafe(for: result))
            Text(NarrativeContent.patientFateLine(for: result))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private var newRecordBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
            Text("New Record!")
                .font(.caption.weight(.heavy))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.yellow, in: Capsule())
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Accuracy").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    CountUpNumber(value: revealedAccuracy, format: { "\($0)" })
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    Text("%").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Speed Bonus").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("+")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    CountUpNumber(value: revealedSpeedBonus, format: { "\($0)" })
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    Text("pts").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Correct Calls").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(result.correctCount)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                    Text("/ \(result.totalDecisions)").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            HStack {
                Text("Best Streak").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(result.bestCombo)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("BREACH").font(.caption2).foregroundStyle(.tertiary)
                    CountUpNumber(value: revealedBreach, format: { "\($0)" })
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 2) {
                    Text("DISRUPTION").font(.caption2).foregroundStyle(.tertiary)
                    CountUpNumber(value: revealedDisruption, format: { "\($0)" })
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionButtons: some View {
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
    }
}

private struct GradeBadgeView: View {
    let grade: TriageEngine.Grade

    private var tint: Color {
        switch grade {
        case .gold: .yellow
        case .silver: Color(white: 0.75)
        case .bronze: Color(red: 0.72, green: 0.45, blue: 0.2)
        case .failed: .red
        }
    }

    private var icon: String {
        switch grade {
        case .gold, .silver, .bronze: "rosette"
        case .failed: "xmark.seal.fill"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(tint)
            Text(grade == .failed ? "No Grade" : grade.rawValue)
                .font(.headline)
                .foregroundStyle(tint)
        }
    }
}

#Preview("Results — Gold") {
    ResultsView(
        result: .init(
            outcome: .cleared, grade: .gold, accuracy: 96, speedBonus: 22,
            finalBreach: 0, finalDisruption: 5, correctCount: 11, totalDecisions: 11,
            bestCombo: 9, rareEventOccurred: false
        ),
        best: .init(grade: .gold, accuracy: 96, bestCombo: 9),
        isNewBestCombo: true,
        isNewBestAccuracy: false,
        onReplay: {}, onExit: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Results — Failed") {
    ResultsView(
        result: .init(
            outcome: .breached, grade: .failed, accuracy: 54, speedBonus: 4,
            finalBreach: 100, finalDisruption: 25, correctCount: 6, totalDecisions: 11,
            bestCombo: 4, rareEventOccurred: true
        ),
        best: .init(grade: .silver, accuracy: 78, bestCombo: 6),
        isNewBestCombo: false,
        isNewBestAccuracy: false,
        onReplay: {}, onExit: {}
    )
    .preferredColorScheme(.dark)
}
