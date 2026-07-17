import Foundation

/// Rules for one Access Lockdown challenge: a short tile sequence plays,
/// then the player repeats it by tapping the same tiles in order. A full,
/// correct repeat succeeds; any wrong tap ends it immediately. No SwiftUI
/// import — AccessLockdownView renders this.
@Observable
final class AccessLockdownEngine {
    enum Phase: Equatable {
        case showing
        case inputting
        case finished
    }

    private(set) var sequence: [Int] = []
    private(set) var highlightedTile: Int?
    private(set) var playerIndex = 0
    private(set) var phase: Phase = .showing
    private(set) var isFinished = false

    var onFinished: ((Bool) -> Void)?
    var onWrongTap: (() -> Void)?

    private var playTask: Task<Void, Never>?

    deinit { playTask?.cancel() }

    func start() {
        let length = Int.random(in: GameConfig.AccessLockdown.sequenceLengthRange)
        sequence = (0..<length).map { _ in Int.random(in: 0..<GameConfig.AccessLockdown.tileCount) }
        playerIndex = 0
        phase = .showing
        isFinished = false
        highlightedTile = nil

        playTask?.cancel()
        playTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(500))
            for tile in sequence {
                guard !Task.isCancelled else { return }
                await MainActor.run { self.highlightedTile = tile }
                try? await Task.sleep(for: .seconds(GameConfig.AccessLockdown.revealIntervalPerTile * 0.65))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.highlightedTile = nil }
                try? await Task.sleep(for: .seconds(GameConfig.AccessLockdown.revealIntervalPerTile * 0.35))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { self.phase = .inputting }
        }
    }

    func stop() {
        playTask?.cancel()
    }

    func tapTile(_ index: Int) {
        guard phase == .inputting, !isFinished, !sequence.isEmpty else { return }
        if index == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex == sequence.count {
                finish(success: true)
            }
        } else {
            onWrongTap?()
            finish(success: false)
        }
    }

    private func finish(success: Bool) {
        guard !isFinished else { return }
        isFinished = true
        phase = .finished
        playTask?.cancel()
        onFinished?(success)
    }
}
