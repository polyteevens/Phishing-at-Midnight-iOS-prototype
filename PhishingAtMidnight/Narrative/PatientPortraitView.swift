import SwiftUI

/// A simple vector stand-in "portrait" — not real illustration, just enough
/// shape and color to put a face on the stakes. Swap for a real illustrated
/// asset later without touching any call site; this view's one parameter
/// (`isSafe`) is the whole contract.
struct PatientPortraitView: View {
    let isSafe: Bool

    private var tint: Color { isSafe ? .mint : Color(white: 0.42) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(isSafe ? 0.32 : 0.1), Color.clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 56
                    )
                )
            Circle()
                .strokeBorder(tint.opacity(isSafe ? 0.6 : 0.22), lineWidth: 2)
            VStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(tint.opacity(isSafe ? 0.95 : 0.4))
                heartbeatLine
            }
        }
        .frame(width: 84, height: 84)
        .animation(.easeInOut(duration: 0.6), value: isSafe)
    }

    private var heartbeatLine: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 6))
            path.addLine(to: CGPoint(x: 12, y: 6))
            path.addLine(to: CGPoint(x: 16, y: -4))
            path.addLine(to: CGPoint(x: 20, y: 14))
            path.addLine(to: CGPoint(x: 24, y: 6))
            path.addLine(to: CGPoint(x: 36, y: 6))
        }
        .stroke(tint.opacity(isSafe ? 0.9 : 0.32), lineWidth: 1.6)
        .frame(width: 36, height: 16)
    }
}

#Preview("Safe") {
    ZStack {
        Color.black.ignoresSafeArea()
        PatientPortraitView(isSafe: true)
    }
}

#Preview("Dim") {
    ZStack {
        Color.black.ignoresSafeArea()
        PatientPortraitView(isSafe: false)
    }
}
