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

    enum Combo {
        /// Consecutive confident-correct calls (Quarantine-on-dangerous or
        /// Allow-on-legit) needed to reach each multiplier tier. A wrong call
        /// or a Flag resets the streak to 0 and the multiplier to the base tier.
        static let tierThresholds: [Int] = [3, 6, 10]
        /// Multiplier applied to a correct decision's speed bonus at each tier
        /// — index 0 is the base (no streak yet), then one entry per threshold.
        static let tierMultipliers: [Double] = [1, 2, 3, 4]

        /// The multiplier for a given streak length.
        static func multiplier(forStreak streak: Int) -> Double {
            var tier = 0
            for threshold in tierThresholds where streak >= threshold {
                tier += 1
            }
            return tierMultipliers[min(tier, tierMultipliers.count - 1)]
        }
    }

    enum Tension {
        /// Breach meter value at which the presentation shifts from Calm to
        /// Pressure (drone thickens, colors warm).
        static let pressureThreshold: Double = 30
        /// Breach meter value at which the presentation shifts to Critical
        /// (screen edges pulse, heartbeat kicks in, haptics warn hard).
        static let criticalThreshold: Double = 70
    }

    enum Juice {
        /// How long to freeze the tick loop on a big moment (a mistake, or
        /// crossing into Critical) — the "hit-stop" that makes impact land.
        static let hitStopDuration: TimeInterval = 0.08
        /// Screen-shake duration for a mistake beat.
        static let shakeDuration: TimeInterval = 0.4
        /// How long a flying "+N" score popup takes to rise and fade.
        static let scorePopupDuration: TimeInterval = 0.9
    }

    enum RareEvent {
        /// Chance a given run gets a coordinated-attack burst at all. Kept
        /// low on purpose — it's a variable reward, not a regular beat.
        static let probabilityPerRun: Double = 0.3
        /// The burst fires somewhere in this fraction-of-mission-duration
        /// window, so it never opens or closes the run.
        static let triggerWindow: ClosedRange<Double> = 0.35...0.7
        /// How many already-pending emails get pulled forward into the burst.
        static let burstCount: Int = 3
        /// Spacing between clustered burst arrivals.
        static let burstArrivalStagger: TimeInterval = 0.5
        /// Click-timer range forced onto dangerous emails caught in the burst
        /// — noticeably tighter than even the "hard" range.
        static let burstClickTimerRange: ClosedRange<Double> = 6...11
    }
}
