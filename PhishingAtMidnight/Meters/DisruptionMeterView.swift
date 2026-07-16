import SwiftUI

/// Operational-failure meter: rises when the player quarantines a
/// legitimate email (friendly fire).
struct DisruptionMeterView: View {
    let value: Double

    var body: some View {
        MeterBarView(
            title: "Disruption",
            value: value,
            tint: .orange,
            icon: "bolt.trianglebadge.exclamationmark"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        DisruptionMeterView(value: 0)
        DisruptionMeterView(value: 45)
        DisruptionMeterView(value: 90)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
