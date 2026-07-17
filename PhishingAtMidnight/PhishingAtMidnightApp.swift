import SwiftUI

@main
struct PhishingAtMidnightApp: App {
    var body: some Scene {
        WindowGroup {
            // Main entry point is the newer "Midnight Breach" mission.
            // The original email-triage mission (StartView -> GameFlowView)
            // remains in the project, unused, in case any of it gets reused.
            BreachStartView()
                .preferredColorScheme(.dark)
        }
    }
}
