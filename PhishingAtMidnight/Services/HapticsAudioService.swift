import AVFoundation
import CoreHaptics

/// The sensory layer, kept behind one small service so placeholder audio can
/// be swapped for real assets without touching game logic. Views call the
/// semantic methods below; per-decision confirmation itself is also wired via
/// SwiftUI's `.sensoryFeedback` modifier in TriageView for the simplest
/// one-shot success/warning tap. This service handles what `.sensoryFeedback`
/// can't: a continuous, intensity-driven tension pulse, a heartbeat that
/// speeds up under pressure, distinct stingers for every kind of moment, and
/// looping ambient audio whose density tracks the run's tension state.
final class HapticsAudioService: NSObject {
    private var engine: CHHapticEngine?
    private var tensionPlayer: CHHapticAdvancedPatternPlayer?
    private var heartbeatPlayer: CHHapticAdvancedPatternPlayer?
    private var ambientPlayer: AVAudioPlayer?
    private var oneShotPlayers: [AVAudioPlayer] = []
    private(set) var isHapticsAvailable = false

    override init() {
        super.init()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            engine.stoppedHandler = { _ in }
            try engine.start()
            self.engine = engine
            isHapticsAvailable = true
        } catch {
            isHapticsAvailable = false
        }
    }

    // MARK: - One-shot SFX
    // Looks up "<name>.m4a" / ".mp3" / ".caf" in the bundle and no-ops
    // silently if the asset hasn't been added yet — drop a file in with the
    // matching name and it starts playing with no code changes.

    private func playSFX(_ name: String, volume: Float = 0.85) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
            ?? Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        player.volume = volume
        player.prepareToPlay()
        oneShotPlayers.append(player)
        player.play()
    }

    // MARK: - Ambient audio

    func playAmbient() {
        guard ambientPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "ambient_tension", withExtension: "m4a")
            ?? Bundle.main.url(forResource: "ambient_tension", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.enableRate = true
            player.volume = 0.3
            player.prepareToPlay()
            player.play()
            ambientPlayer = player
        } catch {
            ambientPlayer = nil
        }
    }

    func stopAmbient() {
        ambientPlayer?.stop()
        ambientPlayer = nil
    }

    /// Drives the drone's density — denser, higher, more urgent — purely via
    /// playback rate and volume on the one ambient loop, so no extra tension
    /// tiers of audio assets are required.
    func updateAmbientIntensity(for state: TriageEngine.TensionState) {
        guard let ambientPlayer else { return }
        switch state {
        case .calm:
            ambientPlayer.rate = 1.0
            ambientPlayer.volume = 0.3
        case .pressure:
            ambientPlayer.rate = 1.12
            ambientPlayer.volume = 0.4
        case .critical:
            ambientPlayer.rate = 1.28
            ambientPlayer.volume = 0.52
        }
    }

    // MARK: - Rising tension pulse

    /// Call whenever Breach or Disruption changes. Starts, updates, or stops
    /// a continuous haptic rumble scaled to the worse of the two meters.
    func updateTension(breach: Double, disruption: Double) {
        guard isHapticsAvailable, let engine else { return }
        let intensity = Float(max(breach, disruption) / GameConfig.Meters.failThreshold)

        guard intensity > 0.05 else {
            stopTension()
            return
        }

        do {
            if let tensionPlayer {
                try tensionPlayer.sendParameters(
                    [CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)],
                    atTime: CHHapticTimeImmediate
                )
            } else {
                let pattern = try Self.tensionPattern(intensity: intensity)
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                try player.start(atTime: CHHapticTimeImmediate)
                tensionPlayer = player
            }
        } catch {
            tensionPlayer = nil
        }
    }

    func stopTension() {
        try? tensionPlayer?.stop(atTime: CHHapticTimeImmediate)
        tensionPlayer = nil
    }

    private static func tensionPattern(intensity: Float) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
            ],
            relativeTime: 0,
            duration: 30
        )
        return try CHHapticPattern(events: [event], parameters: [])
    }

    // MARK: - Heartbeat

    /// Starts, updates, or stops a haptic "lub-dub" that speeds up as the
    /// worse meter climbs from GameConfig.Tension.criticalThreshold to 100.
    /// This one element does more for felt tension than anything visual.
    func updateHeartbeat(worstMeter: Double) {
        guard isHapticsAvailable, let engine else { return }
        guard worstMeter >= GameConfig.Tension.criticalThreshold else {
            stopHeartbeat()
            return
        }

        let span = max(1, GameConfig.Meters.failThreshold - GameConfig.Tension.criticalThreshold)
        let t = min(1, (worstMeter - GameConfig.Tension.criticalThreshold) / span)
        let rate = 1.0 + Float(t) * 1.2

        if let heartbeatPlayer {
            heartbeatPlayer.playbackRate = rate
        } else {
            do {
                let pattern = try Self.heartbeatPattern()
                let player = try engine.makeAdvancedPlayer(with: pattern)
                player.loopEnabled = true
                player.playbackRate = rate
                try player.start(atTime: CHHapticTimeImmediate)
                heartbeatPlayer = player
            } catch {
                heartbeatPlayer = nil
            }
        }
    }

    func stopHeartbeat() {
        try? heartbeatPlayer?.stop(atTime: CHHapticTimeImmediate)
        heartbeatPlayer = nil
    }

    private static func heartbeatPattern() throws -> CHHapticPattern {
        let lub = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
        ], relativeTime: 0)
        let dub = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
        ], relativeTime: 0.16)
        // A near-silent event pads the loop out to ~0.85s so it reads as a
        // resting pulse rather than a stutter; playbackRate compresses this
        // gap as tension climbs.
        let hold = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.001),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0),
        ], relativeTime: 0.85)
        return try CHHapticPattern(events: [lub, dub, hold], parameters: [])
    }

    // MARK: - Per-decision stingers

    /// A firm, satisfying tap — the payoff for a confident correct call.
    /// Sharper and slightly stronger at higher combo multipliers.
    func playCorrectCall(comboMultiplier: Double) {
        playSFX("sfx_correct")
        guard isHapticsAvailable, let engine else { return }
        let intensity = min(1.0, 0.55 + 0.1 * Float(comboMultiplier))
        let sharpness = min(1.0, 0.55 + 0.08 * Float(comboMultiplier))
        do {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: 0)
            let player = try engine.makePlayer(with: try CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    /// A harsh, ugly buzz for a real mistake (wrong Allow of a dangerous
    /// email, wrong Quarantine of a legit one, or an auto-click).
    func playMistake() {
        playSFX("sfx_mistake")
        guard isHapticsAvailable, let engine else { return }
        do {
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85),
            ], relativeTime: 0, duration: 0.25)
            let player = try engine.makePlayer(with: try CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    /// A quieter cue for when Flag breaks a streak without a meter hit —
    /// felt, but not punishing the way a real mistake is.
    func playComboBreak() {
        playSFX("sfx_combo_break")
        guard isHapticsAvailable, let engine else { return }
        do {
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ], relativeTime: 0)
            let player = try engine.makePlayer(with: try CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    /// Sells the moment a coordinated attack starts — a hit, then a rumble.
    func playRareEventStart() {
        playSFX("sfx_rare_event")
        guard isHapticsAvailable, let engine else { return }
        do {
            let hit = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
            ], relativeTime: 0)
            let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
            ], relativeTime: 0.1, duration: 0.4)
            let player = try engine.makePlayer(with: try CHHapticPattern(events: [hit, rumble], parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    // MARK: - Mission-end & results beats

    /// Fires the instant a run ends — the immediate impact of the outcome.
    func missionEndBeat(outcome: TriageEngine.Outcome) {
        guard isHapticsAvailable, let engine else { return }
        do {
            let pattern: CHHapticPattern
            switch outcome {
            case .cleared, .timeUp:
                pattern = try Self.successBeat()
            case .breached, .disrupted:
                pattern = try Self.failureBeat()
            }
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Best-effort feedback; a missed beat isn't worth surfacing to the player.
        }
    }

    /// Fires on the Results screen itself, timed to the grade reveal — the
    /// run's actual payoff, distinct from the immediate end-of-run beat.
    func playResultsSting(grade: TriageEngine.Grade) {
        playSFX(grade == .failed ? "sfx_result_fail" : "sfx_result_success")
        guard isHapticsAvailable, let engine else { return }
        do {
            let pattern = grade == .failed ? try Self.failureBeat() : try Self.successBeat()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    /// Generic success/failure beat for missions that don't share
    /// TriageEngine's Grade/Outcome types (e.g. Midnight Breach) — same
    /// underlying patterns, no cross-mission coupling.
    func playImpactBeat(isPositive: Bool) {
        playSFX(isPositive ? "sfx_result_success" : "sfx_result_fail")
        guard isHapticsAvailable, let engine else { return }
        do {
            let pattern = isPositive ? try Self.successBeat() : try Self.failureBeat()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
    }

    private static func successBeat() throws -> CHHapticPattern {
        let first = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
            ],
            relativeTime: 0
        )
        let second = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
            ],
            relativeTime: 0.12
        )
        return try CHHapticPattern(events: [first, second], parameters: [])
    }

    private static func failureBeat() throws -> CHHapticPattern {
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9),
            ],
            relativeTime: 0,
            duration: 0.5
        )
        return try CHHapticPattern(events: [rumble], parameters: [])
    }
}

extension HapticsAudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        oneShotPlayers.removeAll { $0 === player }
    }
}
