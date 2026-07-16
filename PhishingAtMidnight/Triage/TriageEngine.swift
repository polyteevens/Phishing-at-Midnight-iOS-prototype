import Foundation

/// Game rules, meters, timers, combo streak, tension state, and the rare
/// coordinated-attack event for one Triage run. Deliberately has no SwiftUI
/// import — TriageView renders this, it never drives the rules.
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

    /// The mood the presentation should be in right now, driven entirely by
    /// the Breach meter — see GameConfig.Tension for the cutoffs.
    enum TensionState: Equatable {
        case calm
        case pressure
        case critical
    }

    /// What kind of feedback beat a resolved decision deserves.
    enum CallOutcomeKind: Equatable {
        case confidentCorrect
        case mistakeBreach
        case mistakeDisruption
        case flagged
    }

    /// A one-shot signal TriageView observes (via `.onChange`) to fire the
    /// right juice for whatever just happened — particles and a flying score
    /// for a confident correct call, a flash/stamp/shake for a real mistake,
    /// a quieter "shatter" cue when Flag breaks a streak without a meter hit.
    struct DecisionFeedback: Identifiable, Equatable {
        let id = UUID()
        let kind: CallOutcomeKind
        let decision: Decision
        let pointsEarned: Double
        let comboStreak: Int
        let comboMultiplier: Double
        let brokenStreak: Int
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
        let bestCombo: Int
        let rareEventOccurred: Bool
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
        let comboMultiplierAtDecision: Double
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

    private(set) var comboStreak: Int = 0
    private(set) var comboMultiplier: Double = 1.0
    private(set) var bestComboThisRun: Int = 0
    private(set) var lastFeedback: DecisionFeedback?

    private(set) var rareEventActive: Bool = false
    private(set) var rareEventTriggerToken: Int = 0
    private(set) var criticalEnteredToken: Int = 0

    var missionDuration: TimeInterval { GameConfig.Timing.missionDuration }
    var timeRemaining: TimeInterval { max(0, missionDuration - elapsed) }

    var tensionState: TensionState {
        if breachMeter >= GameConfig.Tension.criticalThreshold { return .critical }
        if breachMeter >= GameConfig.Tension.pressureThreshold { return .pressure }
        return .calm
    }

    private let fullPool: [Specimen]
    private var pendingArrivals: [InboxItem] = []
    private var decisions: [DecisionRecord] = []
    private var tickTask: Task<Void, Never>?

    private var previousTensionState: TensionState = .calm
    private var hitStopTicksRemaining: Int = 0
    private var rareEventArmed: Bool = false
    private var rareEventFireAt: TimeInterval = .infinity
    private var rareEventEndsAt: TimeInterval = 0
    private var rareEventFiredThisRun: Bool = false

    private var hitStopTicks: Int {
        max(1, Int((GameConfig.Juice.hitStopDuration / 0.1).rounded()))
    }

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

        comboStreak = 0
        comboMultiplier = 1.0
        bestComboThisRun = 0
        lastFeedback = nil
        rareEventActive = false
        hitStopTicksRemaining = 0
        previousTensionState = .calm
        rareEventFiredThisRun = false

        rareEventArmed = Double.random(in: 0...1) < GameConfig.RareEvent.probabilityPerRun
        if rareEventArmed {
            let windowStart = missionDuration * GameConfig.RareEvent.triggerWindow.lowerBound
            let windowEnd = missionDuration * GameConfig.RareEvent.triggerWindow.upperBound
            rareEventFireAt = Double.random(in: windowStart...windowEnd)
        } else {
            rareEventFireAt = .infinity
        }

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

        if hitStopTicksRemaining > 0 {
            hitStopTicksRemaining -= 1
            return
        }

        elapsed += deltaTime

        if rareEventArmed && elapsed >= rareEventFireAt {
            rareEventArmed = false
            triggerRareEvent()
        }
        if rareEventActive && elapsed >= rareEventEndsAt {
            rareEventActive = false
        }

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

        let currentTension = tensionState
        if currentTension == .critical && previousTensionState != .critical {
            hitStopTicksRemaining = max(hitStopTicksRemaining, hitStopTicks)
            criticalEnteredToken += 1
        }
        previousTensionState = currentTension

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

    // MARK: - Rare event

    private func triggerRareEvent() {
        let dangerousPendingIndices = pendingArrivals.indices.filter { pendingArrivals[$0].specimen.isDangerous }
        guard !dangerousPendingIndices.isEmpty else { return }

        let chosenIndices = Array(dangerousPendingIndices.shuffled().prefix(GameConfig.RareEvent.burstCount)).sorted(by: >)
        var burst: [InboxItem] = []
        for index in chosenIndices {
            burst.append(pendingArrivals.remove(at: index))
        }

        var clusterTime = elapsed + 0.2
        let rescheduled = burst.map { item -> InboxItem in
            let deadline = clusterTime + Double.random(in: GameConfig.RareEvent.burstClickTimerRange)
            let newItem = InboxItem(
                id: item.id,
                specimen: item.specimen,
                displayName: item.displayName,
                displayTimestamp: item.displayTimestamp,
                arrivalTime: clusterTime,
                clickDeadline: deadline
            )
            clusterTime += GameConfig.RareEvent.burstArrivalStagger
            return newItem
        }

        pendingArrivals.append(contentsOf: rescheduled)
        pendingArrivals.sort { $0.arrivalTime < $1.arrivalTime }

        rareEventActive = true
        rareEventEndsAt = clusterTime + 4
        rareEventFiredThisRun = true
        rareEventTriggerToken += 1
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

        let isConfidentCorrect = weight >= 1.0
        let brokenStreak = (!isConfidentCorrect && comboStreak > 0) ? comboStreak : 0

        var pointsEarned: Double = 0
        if isConfidentCorrect {
            comboStreak += 1
            comboMultiplier = GameConfig.Combo.multiplier(forStreak: comboStreak)
            bestComboThisRun = max(bestComboThisRun, comboStreak)
            let ratio = max(0, 1 - (timeToDecide / (2 * GameConfig.Scoring.speedBonusFullCreditWindow)))
            pointsEarned = GameConfig.Scoring.speedBonusMaxPerDecision * ratio * comboMultiplier
        } else {
            comboStreak = 0
            comboMultiplier = 1.0
        }

        decisions.append(DecisionRecord(
            isDangerous: isDangerous,
            decision: resolvedDecision,
            correct: correct,
            weight: weight,
            timeToDecide: timeToDecide,
            comboMultiplierAtDecision: isConfidentCorrect ? comboMultiplier : 1.0
        ))

        let kind: CallOutcomeKind
        if isConfidentCorrect {
            kind = .confidentCorrect
        } else if autoClicked || (resolvedDecision == .allow && isDangerous) {
            kind = .mistakeBreach
        } else if resolvedDecision == .quarantine && !isDangerous {
            kind = .mistakeDisruption
        } else {
            kind = .flagged
        }

        lastFeedback = DecisionFeedback(
            kind: kind,
            decision: resolvedDecision,
            pointsEarned: pointsEarned,
            comboStreak: comboStreak,
            comboMultiplier: comboMultiplier,
            brokenStreak: brokenStreak
        )

        if kind == .mistakeBreach || kind == .mistakeDisruption {
            hitStopTicksRemaining = max(hitStopTicksRemaining, hitStopTicks)
        } else if kind == .confidentCorrect && resolvedDecision == .quarantine {
            hitStopTicksRemaining = max(hitStopTicksRemaining, hitStopTicks)
        }
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
                timeToDecide: elapsed - item.arrivalTime,
                comboMultiplierAtDecision: 1.0
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
            return partial + GameConfig.Scoring.speedBonusMaxPerDecision * ratio * record.comboMultiplierAtDecision
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
            totalDecisions: total,
            bestCombo: bestComboThisRun,
            rareEventOccurred: rareEventFiredThisRun
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
