import SwiftUI

/// A status bar for Breach (bad when high) or Stability (bad when low).
/// Visually similar to MeterBarView (which the original mission uses) but
/// with a `badWhenHigh` flag so "critical" pulses in the correct direction
/// for either kind of meter.
struct BreachMeterRow: View {
    let title: String
    let value: Double // always 0...100
    let tint: Color
    let icon: String
    let badWhenHigh: Bool

    private var clamped: Double { min(100, max(0, value)) }

    private var isCritical: Bool {
        badWhenHigh ? clamped >= 70 : clamped <= 30
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
                        .frame(width: geometry.size.width * clamped / 100)
                        .animation(.spring(response: 0.45, dampingFraction: 0.62), value: clamped)
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) meter")
        .accessibilityValue("\(Int(clamped)) of 100")
    }
}

#Preview {
    VStack(spacing: 20) {
        BreachMeterRow(title: "BREACH", value: 22, tint: .red, icon: "shield.lefthalf.filled.trianglebadge.exclamationmark", badWhenHigh: true)
        BreachMeterRow(title: "STABILITY", value: 24, tint: .cyan, icon: "waveform.path.ecg", badWhenHigh: false)
        BreachMeterRow(title: "STABILITY", value: 90, tint: .cyan, icon: "waveform.path.ecg", badWhenHigh: false)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
