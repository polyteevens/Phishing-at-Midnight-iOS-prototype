import SwiftUI

/// Shared rendering for the Breach and Disruption meters — same visual
/// language, different tint/label/icon. BreachMeterView and
/// DisruptionMeterView are thin wrappers over this.
struct MeterBarView: View {
    let title: String
    let value: Double
    let tint: Color
    let icon: String

    private var clamped: Double {
        min(GameConfig.Meters.failThreshold, max(0, value))
    }

    private var isCritical: Bool {
        clamped >= GameConfig.Meters.failThreshold * 0.7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .symbolEffect(.pulse, options: .repeating, isActive: isCritical)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(Int(clamped))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: geometry.size.width * clamped / GameConfig.Meters.failThreshold)
                        // Underdamped spring so a spike overshoots slightly
                        // before settling — a jump should feel like a surge.
                        .animation(.spring(response: 0.45, dampingFraction: 0.62), value: clamped)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) meter")
        .accessibilityValue("\(Int(clamped)) of \(Int(GameConfig.Meters.failThreshold))")
    }
}

#Preview("Meter states") {
    VStack(spacing: 20) {
        MeterBarView(title: "Breach", value: 10, tint: .red, icon: "shield.lefthalf.filled.trianglebadge.exclamationmark")
        MeterBarView(title: "Breach", value: 55, tint: .red, icon: "shield.lefthalf.filled.trianglebadge.exclamationmark")
        MeterBarView(title: "Breach", value: 85, tint: .red, icon: "shield.lefthalf.filled.trianglebadge.exclamationmark")
        MeterBarView(title: "Disruption", value: 40, tint: .orange, icon: "bolt.trianglebadge.exclamationmark")
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
