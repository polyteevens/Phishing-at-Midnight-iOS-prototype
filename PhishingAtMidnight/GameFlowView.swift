import SwiftUI

/// Owns one play session: Briefing (shown once per session, skippable after
/// its first-ever view), then the Triage ↔ Results loop — Replay starts a
/// fresh, ramped run without replaying the Briefing. Difficulty ramps off
/// GameProgressStore's persisted lifetime replay count, not a per-session
/// counter, so the game keeps getting harder across app launches.
struct GameFlowView: View {
    enum Phase: Equatable {
        case briefing
        case triage
        case results(TriageEngine.RunResult)
    }

    let pool: [Specimen]
    let onExit: () -> Void

    @State private var progress = GameProgressStore()
    @State private var phase: Phase = .briefing
    @State private var runToken = 0

    var body: some View {
        switch phase {
        case .briefing:
            BriefingView {
                phase = .triage
            }
        case .triage:
            TriageView(pool: pool, replayCount: progress.totalReplays) { result in
                progress.recordRun(result)
                phase = .results(result)
            }
            .id(runToken)
        case .results(let result):
            ResultsView(
                result: result,
                best: progress.bestGrade.map { .init(grade: $0, accuracy: progress.bestAccuracy) },
                onReplay: {
                    runToken += 1
                    phase = .triage
                },
                onExit: onExit
            )
        }
    }
}

#Preview {
    GameFlowView(pool: PreviewData.pool, onExit: {})
        .preferredColorScheme(.dark)
}
