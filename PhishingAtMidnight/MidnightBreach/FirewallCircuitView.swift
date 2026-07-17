import SwiftUI

/// Tap circuit tiles to rotate them into alignment before the timer runs
/// out. Tactile and visual: each tap springs the tile with a little
/// overshoot, and an aligned tile glows green. Running out the clock sparks
/// and shakes the screen.
struct FirewallCircuitView: View {
    let node: BreachNodeKind
    let onMistake: () -> Void
    let onComplete: (Bool) -> Void

    @State private var engine = FirewallCircuitEngine()
    @State private var haptics = HapticsAudioService()
    @State private var shakeTrigger = 0
    @State private var burstEvents: [UUID] = []

    var body: some View {
        ZStack {
            CinematicBackgroundView()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(node.rawValue)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.cyan)
                    Text("Align every tile before time runs out.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                Text(timeString(engine.timeRemaining))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(engine.timeRemaining < 3 ? .red : .white)

                HStack(spacing: 14) {
                    ForEach(engine.tiles) { tile in
                        Button {
                            engine.rotateTile(tile.id)
                            haptics.playCorrectCall(comboMultiplier: 1)
                        } label: {
                            CircuitTileView(rotationSteps: tile.rotationSteps)
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.isFinished)
                    }
                }

                Spacer()
            }

            ZStack {
                ForEach(burstEvents, id: \.self) { id in
                    ParticleBurstView(color: .green)
                        .frame(width: 200, height: 120)
                        .id(id)
                }
            }
            .allowsHitTesting(false)
        }
        .shake(trigger: shakeTrigger)
        .onAppear {
            engine.onFinished = { success in
                if success {
                    haptics.playCorrectCall(comboMultiplier: 3)
                    let burstID = UUID()
                    burstEvents.append(burstID)
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        burstEvents.removeAll { $0 == burstID }
                    }
                } else {
                    onMistake()
                    haptics.playMistake()
                    shakeTrigger += 1
                }
                haptics.playImpactBeat(isPositive: success)
                onComplete(success)
            }
            engine.start()
        }
        .onDisappear { engine.stop() }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", interval)
    }
}

private struct CircuitTileView: View {
    let rotationSteps: Int

    private var isAligned: Bool { rotationSteps == 0 }

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isAligned ? Color.green : Color.orange, lineWidth: 2)
            )
            .overlay(
                Image(systemName: "arrow.up")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isAligned ? .green : .orange)
                    .rotationEffect(.degrees(Double(rotationSteps) * 90))
            )
            .frame(width: 54, height: 54)
            .shadow(color: isAligned ? .green.opacity(0.6) : .clear, radius: 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rotationSteps)
    }
}

#Preview {
    FirewallCircuitView(node: .firewallCore, onMistake: {}, onComplete: { _ in })
        .preferredColorScheme(.dark)
}
