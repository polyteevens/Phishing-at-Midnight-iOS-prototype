import AVFoundation
import CoreHaptics

/// The sensory layer, kept behind one small service so placeholder audio can
/// be swapped for real assets without touching game logic. Views call the
/// semantic methods below; per-decision confirmation itself is wired via
/// SwiftUI's `.sensoryFeedback` modifier in TriageView, since that's the
/// simpler tool for a one-shot success/warning tap. This service handles what
/// `.sensoryFeedback` can't: a continuous, intensity-driven tension pulse and
/// a crafted mission-end beat, plus looping ambient audio.
final class HapticsAudioService {
    private var engine: CHHapticEngine?
    private var tensionPlayer: CHHapticAdvancedPatternPlayer?
    private var ambientPlayer: AVAudioPlayer?
    private(set) var isHapticsAvailable = false

    init() {
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

    // MARK: - Ambient audio
    // Looks for "ambient_tension" in the app bundle. No-ops silently if the
    // asset hasn't been added yet — drop in a real file and this starts
    // playing with no code changes.

    func playAmbient() {
        guard ambientPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "ambient_tension", withExtension: "m4a")
            ?? Bundle.main.url(forResource: "ambient_tension", withExtension: "mp3") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0.35
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

    // MARK: - Mission-end consequence beat

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
