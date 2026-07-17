import Foundation

/// Rules, meters, and node/threat timers for one Midnight Breach run.
/// Deliberately has no SwiftUI import — SystemMapView renders this, it
/// never drives the rules. Mirrors TriageEngine's shape (tick loop, meters,
/// a `phase` that ends in a scored result) but is a fresh, independent
/// engine for a different domain.
@Observable
final class SystemMapEngine {
    enum Phase: Equatable {
        case idle
        case running
        case ended(RunResult)
    }

    enum Outcome: Equatable {
        case cleared
        case timeUp
        case breached
        case destabilized
    }

    enum Grade: String, Equatable {
        case s = "S"
        case a = "A"
        case b = "B"
        case failed = "Failed"
    }

    enum CyberFitSignal: String, Equatable {
        case strong = "Strong"
        case developing = "Developing"
        case unclear = "Unclear"
    }

    struct RunResult: Equatable {
        let outcome: Outcome
        let grade: Grade
        let signal: CyberFitSignal
        let finalBreach: Double
        let finalStability: Double
        let threatsResolved: Int
        let threatsFailed: Int
        let totalMistakes: Int
    }

    enum NodeState: Equatable {
        case safe
        case threatened
        case inChallenge
        case secured
    }

    struct Node: Identifiable, Equatable {
        let id: BreachNodeKind
        var state: NodeState = .safe
        /// 0...1 while threatened — how far the pulse has traveled to the core.
        var pulseProgress: Double = 0
        var nextThreatAt: TimeInterval = 0
        var secureUntil: TimeInterval = 0
    }

    struct ActiveChallenge: Identifiable, Equatable {
        let id = UUID()
        let node: BreachNodeKind
        let kind: ChallengeKind
    }

    private(set) var phase: Phase = .idle
    private(set) var breachMeter: Double = 0
    private(set) var stabilityMeter: Double = 100
    private(set) var elapsed: TimeInterval = 0
    private(set) var nodes: [Node] = BreachNodeKind.allCases.map { Node(id: $0) }
    private(set) var activeChallenge: ActiveChallenge?

    private(set) var threatsResolved = 0
    private(set) var threatsFailed = 0
    private(set) var totalMistakes = 0

    var missionDuration: TimeInterval { GameConfig.Breach.missionDuration }
    var timeRemaining: TimeInterval { max(0, missionDuration - elapsed) }

    private var tickTask: Task<Void, Never>?

    deinit { tickTask?.cancel() }

    // MARK: - Lifecycle

    func start() {
        tickTask?.cancel()
        phase = .running
        elapsed = 0
        breachMeter = 0
        stabilityMeter = 100
        threatsResolved = 0
        threatsFailed = 0
        totalMistakes = 0
        activeChallenge = nil
        nodes = BreachNodeKind.allCases.map { kind in
            var node = Node(id: kind)
            node.nextThreatAt = Double.random(in: GameConfig.Breach.initialThreatDelayRange)
            return node
        }

        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.tick(deltaTime: 0.1) }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
    }

    // MARK: - Tick loop

    private func tick(deltaTime: TimeInterval) {
        guard phase == .running else { return }
        elapsed += deltaTime

        for index in nodes.indices {
            guard activeChallenge?.node != nodes[index].id else { continue }

            switch nodes[index].state {
            case .safe:
                if elapsed >= nodes[index].nextThreatAt {
                    nodes[index].state = .threatened
                    nodes[index].pulseProgress = 0
                }
            case .threatened:
                nodes[index].pulseProgress += deltaTime / GameConfig.Breach.pulseTravelDuration
                if nodes[index].pulseProgress >= 1 {
                    breachMeter = min(100, breachMeter + GameConfig.Breach.breachIncrementOnCoreHit)
                    threatsFailed += 1
                    nodes[index].state = .safe
                    nodes[index].pulseProgress = 0
                    nodes[index].nextThreatAt = elapsed + Double.random(in: GameConfig.Breach.threatCooldownRange)
                }
            case .secured:
                if elapsed >= nodes[index].secureUntil {
                    nodes[index].state = .safe
                    nodes[index].nextThreatAt = elapsed + Double.random(in: GameConfig.Breach.threatCooldownRange)
                }
            case .inChallenge:
                break
            }
        }

        checkForEnd()
    }

    private func checkForEnd() {
        guard phase == .running else { return }
        if breachMeter >= GameConfig.Breach.breachFailThreshold {
            finish(outcome: .breached)
        } else if stabilityMeter <= GameConfig.Breach.stabilityFailThreshold {
            finish(outcome: .destabilized)
        } else if elapsed >= missionDuration {
            finish(outcome: .timeUp)
        }
    }

    // MARK: - Player actions

    func tapNode(_ kind: BreachNodeKind) {
        guard phase == .running, activeChallenge == nil else { return }
        guard let index = nodes.firstIndex(where: { $0.id == kind }) else { return }
        guard nodes[index].state == .threatened else { return }
        nodes[index].state = .inChallenge
        activeChallenge = ActiveChallenge(node: kind, kind: kind.challengeKind)
    }

    /// Called by a challenge in progress on every wrong action — felt
    /// immediately as Stability damage, not just at challenge end.
    func reportMistake() {
        guard phase == .running else { return }
        totalMistakes += 1
        stabilityMeter = max(0, stabilityMeter - GameConfig.Breach.stabilityDamagePerMistake)
        checkForEnd()
    }

    func completeChallenge(success: Bool) {
        guard phase == .running, let active = activeChallenge else { return }
        guard let index = nodes.firstIndex(where: { $0.id == active.node }) else { return }

        if success {
            threatsResolved += 1
            nodes[index].state = .secured
            nodes[index].pulseProgress = 0
            nodes[index].secureUntil = elapsed + 1.2
        } else {
            threatsFailed += 1
            breachMeter = min(100, breachMeter + GameConfig.Breach.breachIncrementOnChallengeFail)
            nodes[index].state = .safe
            nodes[index].pulseProgress = 0
            nodes[index].nextThreatAt = elapsed + Double.random(in: GameConfig.Breach.threatCooldownRange)
        }

        activeChallenge = nil
        checkForEnd()
    }

    // MARK: - Grading

    private func finish(outcome: Outcome) {
        tickTask?.cancel()

        let failed = (outcome == .breached || outcome == .destabilized)
        let grade: Grade
        if failed {
            grade = .failed
        } else if breachMeter <= GameConfig.Breach.gradeSMaxBreach && stabilityMeter >= GameConfig.Breach.gradeSMinStability {
            grade = .s
        } else if breachMeter <= GameConfig.Breach.gradeAMaxBreach && stabilityMeter >= GameConfig.Breach.gradeAMinStability {
            grade = .a
        } else {
            grade = .b
        }

        let signal: CyberFitSignal
        switch grade {
        case .s, .a: signal = .strong
        case .b: signal = .developing
        case .failed: signal = .unclear
        }

        let result = RunResult(
            outcome: outcome,
            grade: grade,
            signal: signal,
            finalBreach: breachMeter,
            finalStability: stabilityMeter,
            threatsResolved: threatsResolved,
            threatsFailed: threatsFailed,
            totalMistakes: totalMistakes
        )
        phase = .ended(result)
    }
}
