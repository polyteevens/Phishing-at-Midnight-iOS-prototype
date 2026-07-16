import SwiftUI

/// Owns one play session: Briefing (shown once per session, skippable after
/// its first-ever view), then the Triage ↔ Results loop — Replay starts a
/// fresh, ramped run without replaying the Briefing.
struct GameFlowView: View {
    enum Phase: Equatable {
        case briefing
        case triage
        case results(TriageEngine.RunResult)
    }

    let pool: [Specimen]
    let onExit: () -> Void

    @State private var replayCount: Int
    @State private var phase: Phase = .briefing

    init(pool: [Specimen], replayCount: Int = 0, onExit: @escaping () -> Void) {
        self.pool = pool
        self.onExit = onExit
        _replayCount = State(initialValue: replayCount)
    }

    var body: some View {
        switch phase {
        case .briefing:
            BriefingView {
                phase = .triage
            }
        case .triage:
            TriageView(pool: pool, replayCount: replayCount) { result in
                phase = .results(result)
            }
            .id(replayCount)
        case .results(let result):
            ResultsView(
                result: result,
                onReplay: {
                    replayCount += 1
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
