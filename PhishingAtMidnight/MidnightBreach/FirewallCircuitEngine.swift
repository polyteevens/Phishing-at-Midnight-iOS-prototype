import Foundation

/// Rules for one Firewall Circuit challenge: a row of tiles, each starting
/// misaligned, that the player taps to rotate 90° at a time. The instant
/// every tile reads "aligned" the circuit locks; running out of time first
/// is a failure. No SwiftUI import — FirewallCircuitView renders this.
@Observable
final class FirewallCircuitEngine {
    struct Tile: Identifiable, Equatable {
        let id: Int
        /// 0...3 — each step is a 90° rotation; 0 means aligned/correct.
        var rotationSteps: Int
    }

    private(set) var tiles: [Tile] = []
    private(set) var timeRemaining: TimeInterval = GameConfig.FirewallCircuit.timeLimit
    private(set) var isFinished = false

    var onFinished: ((Bool) -> Void)?

    private var tickTask: Task<Void, Never>?

    deinit { tickTask?.cancel() }

    func start() {
        tiles = (0..<GameConfig.FirewallCircuit.tileCount).map { index in
            Tile(id: index, rotationSteps: Int.random(in: 1...3))
        }
        timeRemaining = GameConfig.FirewallCircuit.timeLimit
        isFinished = false

        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.tick() }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
    }

    private func tick() {
        guard !isFinished else { return }
        timeRemaining = max(0, timeRemaining - 0.1)
        if timeRemaining <= 0 {
            finish(success: false)
        }
    }

    func rotateTile(_ id: Int) {
        guard !isFinished, let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        tiles[index].rotationSteps = (tiles[index].rotationSteps + 1) % 4
        if tiles.allSatisfy({ $0.rotationSteps == 0 }) {
            finish(success: true)
        }
    }

    private func finish(success: Bool) {
        guard !isFinished else { return }
        isFinished = true
        tickTask?.cancel()
        onFinished?(success)
    }
}
