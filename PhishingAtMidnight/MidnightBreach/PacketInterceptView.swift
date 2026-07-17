import SwiftUI

/// Packets drift across a few lanes. Tap the malicious ones (broken lock,
/// corrupted glow, fake-credential icon) before they exit; let clean traffic
/// through untouched. A correct catch snaps with a particle burst and a
/// haptic tap; a mistake flashes red and shakes the screen.
struct PacketInterceptView: View {
    let node: BreachNodeKind
    let onComplete: (Bool) -> Void

    @State private var engine = PacketInterceptEngine()
    @State private var haptics = HapticsAudioService()
    @State private var shakeTrigger = 0
    @State private var flashOpacity: Double = 0
    @State private var burstEvents: [BurstEvent] = []

    private struct BurstEvent: Identifiable {
        let id = UUID()
        let position: CGPoint
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CinematicBackgroundView()

                VStack(spacing: 4) {
                    Text(node.rawValue)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.cyan)
                    Text("Tap corrupted packets. Let clean traffic pass.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                ForEach(engine.packets) { packet in
                    packetButton(packet, in: geo.size)
                        .position(x: geo.size.width * packet.x, y: laneY(packet.lane, in: geo.size))
                }

                ForEach(burstEvents) { burst in
                    ParticleBurstView(color: .green)
                        .frame(width: 120, height: 120)
                        .position(burst.position)
                        .allowsHitTesting(false)
                }

                Color.red.opacity(flashOpacity).allowsHitTesting(false).ignoresSafeArea()
            }
        }
        .shake(trigger: shakeTrigger)
        .onAppear {
            engine.onMistake = { fireMistakeJuice() }
            engine.onFinished = { success in
                haptics.playImpactBeat(isPositive: success)
                onComplete(success)
            }
            engine.start()
        }
        .onDisappear { engine.stop() }
    }

    private func packetButton(_ packet: PacketInterceptEngine.Packet, in size: CGSize) -> some View {
        Button {
            let wasMalicious = packet.isMalicious
            let position = CGPoint(x: size.width * packet.x, y: laneY(packet.lane, in: size))
            engine.tapPacket(packet.id)
            if wasMalicious {
                haptics.playCorrectCall(comboMultiplier: 1)
                spawnBurst(at: position)
            }
        } label: {
            Image(systemName: packet.tellSymbol)
                .font(.title3)
                .foregroundStyle(packet.isMalicious ? .red : .green)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle().stroke(packet.isMalicious ? Color.red.opacity(0.7) : Color.green.opacity(0.5), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func laneY(_ lane: Int, in size: CGSize) -> CGFloat {
        let usableHeight = size.height * 0.55
        let top = size.height * 0.28
        let spacing = usableHeight / CGFloat(GameConfig.PacketIntercept.laneCount)
        return top + spacing * (CGFloat(lane) + 0.5)
    }

    private func spawnBurst(at position: CGPoint) {
        let burst = BurstEvent(position: position)
        burstEvents.append(burst)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            burstEvents.removeAll { $0.id == burst.id }
        }
    }

    private func fireMistakeJuice() {
        haptics.playMistake()
        shakeTrigger += 1
        withAnimation(.easeIn(duration: 0.05)) { flashOpacity = 0.28 }
        withAnimation(.easeOut(duration: 0.3).delay(0.05)) { flashOpacity = 0 }
    }
}

#Preview {
    PacketInterceptView(node: .records, onComplete: { _ in })
        .preferredColorScheme(.dark)
}
