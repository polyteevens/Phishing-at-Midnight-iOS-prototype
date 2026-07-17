import SwiftUI

/// Fast pattern-memory: watch a short sequence light up, then repeat it by
/// tapping the same tiles in order. No explanation beyond one short line —
/// this is meant to be read with the eyes, not with words.
struct AccessLockdownView: View {
    let node: BreachNodeKind
    let onMistake: () -> Void
    let onComplete: (Bool) -> Void

    @State private var engine = AccessLockdownEngine()
    @State private var haptics = HapticsAudioService()
    @State private var shakeTrigger = 0
    @State private var burstEvents: [UUID] = []

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            CinematicBackgroundView()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(node.rawValue)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.cyan)
                    Text(engine.phase == .showing ? "Watch." : "Repeat it.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<GameConfig.AccessLockdown.tileCount, id: \.self) { index in
                        Button {
                            engine.tapTile(index)
                        } label: {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(engine.highlightedTile == index ? Color.cyan.opacity(0.75) : Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                                )
                                .frame(width: 72, height: 72)
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.phase != .inputting)
                        .animation(.easeOut(duration: 0.2), value: engine.highlightedTile)
                    }
                }

                Spacer()
            }

            ZStack {
                ForEach(burstEvents, id: \.self) { id in
                    ParticleBurstView(color: .cyan)
                        .frame(width: 220, height: 220)
                        .id(id)
                }
            }
            .allowsHitTesting(false)
        }
        .shake(trigger: shakeTrigger)
        .onAppear {
            engine.onWrongTap = {
                onMistake()
                haptics.playMistake()
                shakeTrigger += 1
            }
            engine.onFinished = { success in
                if success {
                    haptics.playCorrectCall(comboMultiplier: 3)
                    let burstID = UUID()
                    burstEvents.append(burstID)
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        burstEvents.removeAll { $0 == burstID }
                    }
                }
                haptics.playImpactBeat(isPositive: success)
                onComplete(success)
            }
            engine.start()
        }
        .onDisappear { engine.stop() }
    }
}

#Preview {
    AccessLockdownView(node: .identity, onMistake: {}, onComplete: { _ in })
        .preferredColorScheme(.dark)
}
