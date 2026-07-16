import SwiftUI

/// Security-failure meter: rises when a dangerous email gets "clicked".
struct BreachMeterView: View {
    let value: Double

    var body: some View {
        MeterBarView(
            title: "Breach",
            value: value,
            tint: .red,
            icon: "shield.lefthalf.filled.trianglebadge.exclamationmark"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        BreachMeterView(value: 0)
        BreachMeterView(value: 40)
        BreachMeterView(value: 90)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
