import Foundation

/// Game rules, meters, and timers for one Triage run. Deliberately has no
/// SwiftUI import — TriageView renders this, it never drives the rules.
@Observable
final class TriageEngine {
    enum Phase: Equatable {
        case idle
        case running
        case ended(RunResult)
    }

    enum Outcome: Equatable {
        case cleared
        case timeUp
        case breached
        case disrupted
    }

    enum Grade: String, Equatable {
        case gold = "Gold"
        case silver = "Silver"
        case bronze = "Bronze"
        case failed = "Failed"
    }

    enum Decision: Equatable {
        case quarantine
        case allow
        case flag
    }

    struct RunResult: Equatable {
        let outcome: Outcome
        let grade: Grade
        let accuracy: Double
        let speedBonus: Double
        let finalBreach: Double
        let finalDisruption: Double
        let correctCount: Int
        let totalDecisions: Int
    }

    struct InboxItem: Identifiable, Equatable {
        let id: String
        let specimen: Specimen
        let displayName: String
        let displayTimestamp: String
        let arrivalTime: TimeInterval
        let clickDeadline: TimeInterval?
    }

    private struct DecisionRecord {
        let isDangerous: Bool
        let decision: Decision
        let correct: Bool
        let weight: Double
        let timeToDecide: TimeInterval
    }

    private static let cosmeticTimestamps = [
        "11:42 PM", "11:58 PM", "12:07 AM", "12:19 AM", "12:31 AM",
        "12:44 AM", "12:56 AM", "1:08 AM", "1:21 AM", "1:37 AM",
        "1:49 AM", "2:02 AM", "2:15 AM",
    ]

    private(set) var phase: Phase = .idle
    private(set) var breachMeter: Double = 0
    private(set) var disruptionMeter: Double = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var inbox: [InboxItem] = []
    private(set) var resolvedCount: Int = 0
    private(set) var totalToArrive: Int = 0

    var missionDuration: TimeInterval { GameConfig.Timing.missionDuration }
    var timeRemaining: TimeInterval { max(0, missionDuration - elapsed) }

    private let fullPool: [Specimen]
    private var pendingArrivals: [InboxItem] = []
    private var decisions: [DecisionRecord] = []
    private var tickTask: Task<Void, Never>?

    init(pool: [Specimen]) {
        self.fullPool = pool
    }

    deinit {
        tickTask?.cancel()
    }

    // MARK: - Run lifecycle

    func startRun(replayCount: Int) {
        tickTask?.cancel()

        let drawn = Self.drawRun(from: fullPool, replayCount: replayCount)
        pendingArrivals = drawn.sorted { $0.arrivalTime < $1.arrivalTime }
        totalToArrive = pendingArrivals.count
        inbox = []
        resolvedCount = 0
        decisions = []
        breachMeter = 0
        disruptionMeter = 0
        elapsed = 0
        phase = .running

        tickTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                await MainActor.run { self.tick(deltaTime: 0.1) }
            }
        }
    }

    func endRunEarly() {
        tickTask?.cancel()
    }

    // MARK: - Player decisions

    func decide(_ itemID: String, _ decision: Decision) {
        guard phase == .running, let index = inbox.firstIndex(where: { $0.id == itemID }) else { return }
        let item = inbox.remove(at: index)
        record(item: item, decision: decision, autoClicked: false)
        resolvedCount += 1
        checkForEnd()
    }

    // MARK: - Tick loop

    private func tick(deltaTime: TimeInterval) {
        guard phase == .running else { return }
        elapsed += deltaTime

        while let next = pendingArrivals.first, next.arrivalTime <= elapsed {
            pendingArrivals.removeFirst()
            inbox.append(next)
        }

        var autoClicked: [InboxItem] = []
        inbox.removeAll { item in
            if let deadline = item.clickDeadline, deadline <= elapsed {
                autoClicked.append(item)
                return true
            }
            return false
        }
        for item in autoClicked {
            breachMeter = min(GameConfig.Meters.failThreshold, breachMeter + GameConfig.Meters.breachIncrementPerClick)
            record(item: item, decision: nil, autoClicked: true)
            resolvedCount += 1
        }

        checkForEnd()
    }

    private func checkForEnd() {
        guard phase == .running else { return }

        if breachMeter >= GameConfig.Meters.failThreshold {
            finish(outcome: .breached)
        } else if disruptionMeter >= GameConfig.Meters.failThreshold {
            finish(outcome: .disrupted)
        } else if elapsed >= missionDuration {
            finish(outcome: .timeUp)
        } else if pendingArrivals.isEmpty && inbox.isEmpty && resolvedCount >= totalToArrive && totalToArrive > 0 {
            finish(outcome: .cleared)
        }
    }

    // MARK: - Decision recording & scoring

    private func record(item: InboxItem, decision: Decision?, autoClicked: Bool) {
        let isDangerous = item.specimen.isDangerous
        let timeToDecide = elapsed - item.arrivalTime

        let correct: Bool
        let weight: Double
        let resolvedDecision: Decision

        if autoClicked {
            resolvedDecision = .allow
            correct = false
            weight = 0
        } else {
            resolvedDecision = decision ?? .allow
            switch resolvedDecision {
            case .quarantine:
                correct = isDangerous
                weight = isDangerous ? 1.0 : 0.0
                if !isDangerous {
                    disruptionMeter = min(GameConfig.Meters.failThreshold, disruptionMeter + GameConfig.Meters.disruptionIncrementPerWrongQuarantine)
                }
            case .allow:
                correct = !isDangerous
                weight = isDangerous ? 0.0 : 1.0
                if isDangerous {
                    breachMeter = min(GameConfig.Meters.failThreshold, breachMeter + GameConfig.Meters.breachIncrementPerClick)
                }
            case .flag:
                correct = false
                weight = GameConfig.Scoring.flagScoreMultiplier
            }
        }

        decisions.append(DecisionRecord(
            isDangerous: isDangerous,
            decision: resolvedDecision,
            correct: correct,
            weight: weight,
            timeToDecide: timeToDecide
        ))
    }

    private func finish(outcome: Outcome) {
        tickTask?.cancel()

        // Any items still sitting in the inbox when the shift ends are
        // unresolved calls: they count against accuracy, but don't touch
        // either meter — the shift simply ended before anyone acted.
        for item in inbox {
            decisions.append(DecisionRecord(
                isDangerous: item.specimen.isDangerous,
                decision: .flag,
                correct: false,
                weight: 0,
                timeToDecide: elapsed - item.arrivalTime
            ))
        }
        inbox = []

        let total = decisions.count
        let correctCount = decisions.filter { $0.weight >= 1.0 }.count
        let accuracy = total > 0 ? (decisions.reduce(0) { $0 + $1.weight } / Double(total)) * 100 : 0

        let window = GameConfig.Scoring.speedBonusFullCreditWindow
        let perDecisionSpeedBonus = decisions.reduce(0.0) { partial, record in
            guard record.weight >= 1.0 else { return partial }
            let ratio = max(0, 1 - (record.timeToDecide / (2 * window)))
            return partial + GameConfig.Scoring.speedBonusMaxPerDecision * ratio
        }
        let timeRemainingBonus = (outcome == .cleared)
            ? timeRemaining * GameConfig.Scoring.timeRemainingBonusPerSecond
            : 0
        let speedBonus = perDecisionSpeedBonus + timeRemainingBonus

        let failed = (outcome == .breached || outcome == .disrupted)
        let grade: Grade
        if failed {
            grade = .failed
        } else {
            let worstMeter = max(breachMeter, disruptionMeter)
            if worstMeter <= GameConfig.Scoring.goldMaxMeterValue {
                grade = .gold
            } else if worstMeter <= GameConfig.Scoring.silverMaxMeterValue {
                grade = .silver
            } else {
                grade = .bronze
            }
        }

        let result = RunResult(
            outcome: outcome,
            grade: grade,
            accuracy: accuracy,
            speedBonus: speedBonus,
            finalBreach: breachMeter,
            finalDisruption: disruptionMeter,
            correctCount: correctCount,
            totalDecisions: total
        )
        phase = .ended(result)
    }

    // MARK: - Run generation

    private static func drawRun(from pool: [Specimen], replayCount: Int) -> [InboxItem] {
        let dangerous = pool.filter { $0.isDangerous }
        let legit = pool.filter { !$0.isDangerous }
        guard !dangerous.isEmpty || !legit.isEmpty else { return [] }

        let totalPool = pool.count
        let emailsPerRun = min(GameConfig.PoolComposition.emailsPerRun, totalPool)
        let dangerousShare = totalPool > 0 ? Double(dangerous.count) / Double(totalPool) : 0
        let desiredDangerousCount = min(dangerous.count, Int((Double(emailsPerRun) * dangerousShare).rounded()))
        let desiredLegitCount = min(legit.count, emailsPerRun - desiredDangerousCount)

        let hardRatio = GameConfig.PoolComposition.hardRatio(forReplayCount: replayCount)
        let hardDangerousPool = dangerous.filter { $0.difficulty == .hard }
        let normalDangerousPool = dangerous.filter { $0.difficulty == .normal }
        let hardCount = min(hardDangerousPool.count, Int(floor(Double(desiredDangerousCount) * hardRatio)))
        let normalCount = min(normalDangerousPool.count, desiredDangerousCount - hardCount)

        var drawnSpecimens: [Specimen] = []
        drawnSpecimens.append(contentsOf: hardDangerousPool.shuffled().prefix(hardCount))
        drawnSpecimens.append(contentsOf: normalDangerousPool.shuffled().prefix(normalCount))
        drawnSpecimens.append(contentsOf: legit.shuffled().prefix(desiredLegitCount))
        drawnSpecimens.shuffle()

        let clickRange = GameConfig.PoolComposition.clickTimerRange(forReplayCount: replayCount)
        var arrivalCursor: TimeInterval = Double.random(in: 1.5...3.0)

        return drawnSpecimens.map { specimen in
            let arrival = arrivalCursor
            arrivalCursor += Double.random(in: GameConfig.Timing.arrivalIntervalRange)

            let deadline: TimeInterval?
            if specimen.isDangerous {
                let range = specimen.difficulty == .hard ? GameConfig.Timing.clickTimerRangeHard : clickRange
                deadline = arrival + Double.random(in: range)
            } else {
                deadline = nil
            }

            return InboxItem(
                id: specimen.id,
                specimen: specimen,
                displayName: specimen.senderDisplayNames.randomElement() ?? "Unknown Sender",
                displayTimestamp: cosmeticTimestamps.randomElement() ?? cosmeticTimestamps[0],
                arrivalTime: arrival,
                clickDeadline: deadline
            )
        }
    }
}
