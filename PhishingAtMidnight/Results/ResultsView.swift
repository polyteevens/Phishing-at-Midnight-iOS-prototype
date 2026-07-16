import SwiftUI

/// Episode-style results screen: Accuracy, Speed bonus, Risk-Control grade,
/// a cosmetic skill-unlocked line, and a prominent Replay button — because
/// chasing a better grade is the retention hook even in this prototype.
struct ResultsView: View {
    struct BestStats: Equatable {
        let grade: TriageEngine.Grade
        let accuracy: Double
    }

    let result: TriageEngine.RunResult
    let best: BestStats?
    let onReplay: () -> Void
    let onExit: () -> Void

    private var isFailure: Bool {
        result.outcome == .breached || result.outcome == .disrupted
    }

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
            VStack(spacing: 24) {
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
                .padding(.top, 32)

                GradeBadgeView(grade: result.grade)

                if let best {
                    Text("Best: \(best.grade.rawValue) · \(Int(best.accuracy.rounded()))% accuracy")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                statGrid

                Text(skillUnlockedLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                VStack(spacing: 12) {
                    Button {
                        onReplay()
                    } label: {
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
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var statGrid: some View {
        VStack(spacing: 12) {
            StatRowView(label: "Accuracy", value: "\(Int(result.accuracy.rounded()))", suffix: "%")
            StatRowView(label: "Speed Bonus", value: "+\(Int(result.speedBonus.rounded()))", suffix: "pts")
            StatRowView(label: "Correct Calls", value: "\(result.correctCount)", suffix: "/ \(result.totalDecisions)")
            HStack(spacing: 16) {
                MiniMeterStatView(title: "Breach", value: result.finalBreach, tint: .red)
                MiniMeterStatView(title: "Disruption", value: result.finalDisruption, tint: .orange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

private struct StatRowView: View {
    let label: String
    let value: String
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Text(suffix)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct MiniMeterStatView: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Results — Gold") {
    ResultsView(
        result: .init(
            outcome: .cleared, grade: .gold, accuracy: 96, speedBonus: 22.5,
            finalBreach: 0, finalDisruption: 5, correctCount: 11, totalDecisions: 11,
            bestCombo: 9, rareEventOccurred: false
        ),
        best: .init(grade: .gold, accuracy: 96),
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
        best: .init(grade: .silver, accuracy: 78),
        onReplay: {}, onExit: {}
    )
    .preferredColorScheme(.dark)
}
