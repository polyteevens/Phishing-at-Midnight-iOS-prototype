import SwiftUI

/// Owns the Triage ↔ Results loop for one play session: runs a mission,
/// shows the results screen, and starts a fresh (ramped) run on Replay.
/// BriefingView will be inserted as a phase here once it exists.
struct GameFlowView: View {
    enum Phase: Equatable {
        case triage
        case results(TriageEngine.RunResult)
    }

    let pool: [Specimen]
    let onExit: () -> Void

    @State private var replayCount: Int
    @State private var phase: Phase = .triage

    init(pool: [Specimen], replayCount: Int = 0, onExit: @escaping () -> Void) {
        self.pool = pool
        self.onExit = onExit
        _replayCount = State(initialValue: replayCount)
    }

    var body: some View {
        switch phase {
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
