import SwiftUI

/// A stamped consequence label ("CLICKED", "FRIENDLY FIRE") that slams down
/// with a little overshoot. The caller is responsible for removing it after
/// a beat — this view only handles its own entrance.
struct StampView: View {
    let text: String
    let tint: Color

    @State private var appeared = false

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .tracking(2)
            .foregroundStyle(tint)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint, lineWidth: 4)
            )
            .rotationEffect(.degrees(appeared ? -6 : -18))
            .scaleEffect(appeared ? 1 : 1.6)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                    appeared = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 24) {
            StampView(text: "CLICKED", tint: .red)
            StampView(text: "FRIENDLY FIRE", tint: .orange)
        }
    }
}
