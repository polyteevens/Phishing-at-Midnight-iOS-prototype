import Foundation

/// The human-stakes thread: one named patient whose safety is what tonight's
/// shift is actually protecting, plus Supervisor Morales's reactions to how
/// the run went. Pure content lookups — no game logic lives here, so this
/// is safe to rewrite freely while tuning tone.
enum NarrativeContent {
    static let patientName = "Maya Castillo"
    static let patientContext = "age 9 — post-op cardiac monitoring, room 4"

    static let briefingPatientLine =
        "One name to remember tonight: \(patientName), \(patientContext). Everything you triage touches her chart."

    static func patientFateLine(for result: TriageEngine.RunResult) -> String {
        switch result.outcome {
        case .breached:
            "A phishing link reached the floor tonight. \(patientName)'s monitoring alert was delayed twelve minutes before anyone caught it."
        case .disrupted:
            "\(patientName)'s real lab order got stuck behind the blocks tonight. The floor scrambled to catch it before it mattered."
        case .cleared, .timeUp:
            "\(patientName) is safe tonight. Every real message about her care got through, and nothing dangerous did."
        }
    }

    /// True when the patient came through the shift unharmed — drives
    /// PatientPortraitView's bright/dim state on the Results screen.
    static func patientIsSafe(for result: TriageEngine.RunResult) -> Bool {
        result.outcome == .cleared || result.outcome == .timeUp
    }

    static func moralesReaction(for result: TriageEngine.RunResult) -> String {
        if result.grade == .failed {
            switch result.outcome {
            case .breached:
                return "Morales: We lost control of that inbox tonight. She paid for it. We fix this before the next shift."
            case .disrupted:
                return "Morales: You locked down half the real traffic out there. That's not safe either — it just fails quieter."
            case .cleared, .timeUp:
                return "Morales: Rough one. Shake it off — the next shift is what matters."
            }
        }
        switch result.grade {
        case .gold: return "Morales: Clean work. That's exactly how we keep her safe."
        case .silver: return "Morales: Solid shift. Tighten it up and that's a clean night."
        case .bronze: return "Morales: We got through it. Barely. Let's talk about what slipped."
        case .failed: return "" // unreachable — handled above
        }
    }
}
