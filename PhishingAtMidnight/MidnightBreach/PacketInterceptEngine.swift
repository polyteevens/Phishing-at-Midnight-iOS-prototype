import Foundation

/// Rules for one Packet Intercept challenge: packets drift left-to-right
/// across a few lanes; the player taps malicious ones before they exit.
/// No SwiftUI import — PacketInterceptView renders this.
@Observable
final class PacketInterceptEngine {
    struct Packet: Identifiable, Equatable {
        let id = UUID()
        let isMalicious: Bool
        let lane: Int
        var x: Double // 0...1 progress across the screen
        let speed: Double // screen-widths per second
        let tellSymbol: String
    }

    private static let maliciousTells = ["lock.open.fill", "exclamationmark.triangle.fill", "key.slash"]

    private(set) var packets: [Packet] = []
    private(set) var correctCount = 0
    private(set) var mistakeCount = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var isFinished = false

    var onMistake: (() -> Void)?
    var onCorrectCatch: (() -> Void)?
    var onFinished: ((Bool) -> Void)?

    private var nextSpawnAt: TimeInterval = 0
    private var tickTask: Task<Void, Never>?

    deinit { tickTask?.cancel() }

    func start() {
        packets = []
        correctCount = 0
        mistakeCount = 0
        elapsed = 0
        isFinished = false
        nextSpawnAt = Double.random(in: GameConfig.PacketIntercept.spawnIntervalRange)

        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.tick(deltaTime: 0.05) }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
    }

    private func tick(deltaTime: TimeInterval) {
        guard !isFinished else { return }
        elapsed += deltaTime

        for index in packets.indices {
            packets[index].x += packets[index].speed * deltaTime
        }

        let exitedMalicious = packets.filter { $0.x >= 1.05 && $0.isMalicious }
        if !exitedMalicious.isEmpty {
            mistakeCount += exitedMalicious.count
            onMistake?()
        }
        packets.removeAll { $0.x >= 1.05 }

        if elapsed >= nextSpawnAt {
            spawnPacket()
            nextSpawnAt = elapsed + Double.random(in: GameConfig.PacketIntercept.spawnIntervalRange)
        }

        if elapsed >= GameConfig.PacketIntercept.challengeDuration {
            finish()
        }
    }

    private func spawnPacket() {
        let malicious = Double.random(in: 0...1) < GameConfig.PacketIntercept.maliciousRatio
        packets.append(Packet(
            isMalicious: malicious,
            lane: Int.random(in: 0..<GameConfig.PacketIntercept.laneCount),
            x: 0,
            speed: Double.random(in: GameConfig.PacketIntercept.packetSpeedRange),
            tellSymbol: malicious ? (Self.maliciousTells.randomElement() ?? Self.maliciousTells[0]) : "checkmark.shield.fill"
        ))
    }

    func tapPacket(_ id: UUID) {
        guard !isFinished, let index = packets.firstIndex(where: { $0.id == id }) else { return }
        let packet = packets.remove(at: index)
        if packet.isMalicious {
            correctCount += 1
            onCorrectCatch?()
        } else {
            mistakeCount += 1
            onMistake?()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        tickTask?.cancel()
        let success = mistakeCount <= GameConfig.PacketIntercept.maxMistakesAllowed
        onFinished?(success)
    }
}
