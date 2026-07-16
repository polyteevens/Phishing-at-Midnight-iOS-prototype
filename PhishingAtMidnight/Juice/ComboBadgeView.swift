import SwiftUI

/// Streak + multiplier readout. Bumps on every increase; the caller wraps
/// its presence (`streak >= 2`) in a transition + `.animation(value:)` so
/// a broken streak visibly pops out rather than just vanishing.
struct ComboBadgeView: View {
    let streak: Int
    let multiplier: Double

    @State private var bump = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
            Text("×\(Int(multiplier))")
                .font(.subheadline.weight(.heavy))
            Text("\(streak) streak")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.14), in: Capsule())
        .scaleEffect(bump ? 1.16 : 1.0)
        .onChange(of: streak) { oldValue, newValue in
            guard newValue > oldValue else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.45)) { bump = true }
            Task {
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeOut(duration: 0.18)) { bump = false }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ComboBadgeView(streak: 7, multiplier: 3)
    }
}
