import SwiftUI

/// A pulsing red vignette at the screen edges, visible only in the Critical
/// tension state. Purely decorative — driven off TriageEngine.tensionState.
struct TensionOverlayView: View {
    let state: TriageEngine.TensionState

    @State private var pulse = false

    private var isCritical: Bool { state == .critical }

    var body: some View {
        RadialGradient(
            colors: [Color.clear, Color.red.opacity(isCritical ? (pulse ? 0.4 : 0.18) : 0)],
            center: .center,
            startRadius: 140,
            endRadius: 420
        )
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: isCritical)
        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
    }
}

#Preview("Calm") {
    ZStack { Color.black.ignoresSafeArea(); TensionOverlayView(state: .calm) }
}

#Preview("Critical") {
    ZStack { Color.black.ignoresSafeArea(); TensionOverlayView(state: .critical) }
}
