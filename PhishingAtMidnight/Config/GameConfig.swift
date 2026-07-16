import Foundation

/// Every tunable number for Phishing at Midnight lives here. Balancing the
/// Breach/Disruption tension is the whole game, so this file — not scattered
/// constants — is the one place to change it. See NOTES.md for a plain-English
/// rundown of what each knob does.
enum GameConfig {
    enum Meters {
        /// Added to the Breach meter when a dangerous email gets "clicked"
        /// (its click timer expires, or the player explicitly Allows it).
        static let breachIncrementPerClick: Double = 20
        /// Added to the Disruption meter when the player Quarantines a
        /// legitimate email (friendly fire).
        static let disruptionIncrementPerWrongQuarantine: Double = 25
        /// Either meter reaching this value ends the run as a failure.
        static let failThreshold: Double = 100
    }

    enum Timing {
        /// Total length of a Triage run, in seconds.
        static let missionDuration: TimeInterval = 150
        /// Gap between one email arriving and the next, drawn fresh each time.
        static let arrivalIntervalRange: ClosedRange<Double> = 4...9
        /// Hidden countdown before a dangerous, normal-difficulty email gets
        /// auto-clicked if it isn't quarantined first.
        static let clickTimerRangeNormal: ClosedRange<Double> = 18...30
        /// Same, but for "hard" specimens (used more as replay count rises).
        static let clickTimerRangeHard: ClosedRange<Double> = 10...18
    }

    enum PoolComposition {
        /// How many specimens are drawn from the pool for one run.
        static let emailsPerRun = 11
        /// Fraction of a run's dangerous emails pulled from the "hard" pool
        /// on a first-ever run.
        static let baseHardRatio: Double = 0.15
        /// How much that fraction grows per completed replay.
        static let hardRatioRampPerReplay: Double = 0.10
        static let maxHardRatio: Double = 0.6

        /// Ramped hard-specimen fraction for a given number of prior replays.
        static func hardRatio(forReplayCount replayCount: Int) -> Double {
            min(maxHardRatio, baseHardRatio + Double(replayCount) * hardRatioRampPerReplay)
        }

        /// Ramped click-timer range for a given number of prior replays —
        /// shrinks toward the hard range as the player replays more.
        static func clickTimerRange(forReplayCount replayCount: Int) -> ClosedRange<Double> {
            let t = min(1.0, Double(replayCount) / 6.0)
            let lower = Timing.clickTimerRangeNormal.lowerBound
                + t * (Timing.clickTimerRangeHard.lowerBound - Timing.clickTimerRangeNormal.lowerBound)
            let upper = Timing.clickTimerRangeNormal.upperBound
                + t * (Timing.clickTimerRangeHard.upperBound - Timing.clickTimerRangeNormal.upperBound)
            return lower...upper
        }
    }

    enum Scoring {
        /// A Flag decision always scores at this fraction of a correct,
        /// confident call — a safe hedge, not a free win.
        static let flagScoreMultiplier: Double = 0.5
        /// Max speed-bonus points awarded for a single fast, correct decision.
        static let speedBonusMaxPerDecision: Double = 5
        /// A decision made this many seconds after an email arrives (or less)
        /// earns the full speed bonus; bonus decays to zero by 2x this value.
        static let speedBonusFullCreditWindow: TimeInterval = 6
        /// Bonus points per second of mission time left unused at a clean clear.
        static let timeRemainingBonusPerSecond: Double = 0.5

        /// Risk-Control grade cutoffs, checked against the higher of the two
        /// meters at run end. Only evaluated when the run wasn't failed outright.
        static let goldMaxMeterValue: Double = 25
        static let silverMaxMeterValue: Double = 60
    }
}
