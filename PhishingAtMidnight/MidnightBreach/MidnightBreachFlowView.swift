import SwiftUI

/// Owns one Midnight Breach play session: the system map (with its meters
/// and node taps), whichever challenge is currently active, and the
/// Results screen. Replay resets the engine and returns straight to the map.
struct MidnightBreachFlowView: View {
    enum Phase: Equatable {
        case systemMap
        case results(SystemMapEngine.RunResult)
    }

    let onExit: () -> Void

    @State private var engine = SystemMapEngine()
    @State private var phase: Phase = .systemMap

    var body: some View {
        switch phase {
        case .systemMap:
            systemMapScreen
        case .results(let result):
            BreachResultsView(
                result: result,
                onReplay: {
                    engine = SystemMapEngine()
                    phase = .systemMap
                },
                onExit: onExit
            )
        }
    }

    private var systemMapScreen: some View {
        ZStack {
            CinematicBackgroundView()

            VStack(spacing: 16) {
                header
                SystemMapView(engine: engine, onTapNode: { engine.tapNode($0) })
            }
            .padding()

            if let active = engine.activeChallenge {
                challengeView(for: active)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if engine.phase == .idle {
                engine.start()
            }
        }
        .onChange(of: engine.phase) { _, newPhase in
            if case .ended(let result) = newPhase {
                phase = .results(result)
            }
        }
        .onDisappear { engine.stop() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label(timeString(engine.timeRemaining), systemImage: "clock")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(engine.threatsResolved) contained")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                BreachMeterRow(
                    title: "BREACH", value: engine.breachMeter, tint: .red,
                    icon: "shield.lefthalf.filled.trianglebadge.exclamationmark", badWhenHigh: true
                )
                BreachMeterRow(
                    title: "STABILITY", value: engine.stabilityMeter, tint: .cyan,
                    icon: "waveform.path.ecg", badWhenHigh: false
                )
            }
        }
    }

    @ViewBuilder
    private func challengeView(for active: SystemMapEngine.ActiveChallenge) -> some View {
        switch active.kind {
        case .packetIntercept:
            PacketInterceptView(
                node: active.node,
                onMistake: { engine.reportMistake() },
                onComplete: { success in engine.completeChallenge(success: success) }
            )
        case .firewallCircuit:
            FirewallCircuitView(
                node: active.node,
                onMistake: { engine.reportMistake() },
                onComplete: { success in engine.completeChallenge(success: success) }
            )
        case .accessLockdown:
            AccessLockdownView(
                node: active.node,
                onMistake: { engine.reportMistake() },
                onComplete: { success in engine.completeChallenge(success: success) }
            )
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    MidnightBreachFlowView(onExit: {})
        .preferredColorScheme(.dark)
}
