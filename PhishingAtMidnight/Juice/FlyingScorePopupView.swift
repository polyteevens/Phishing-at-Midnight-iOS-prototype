import SwiftUI

/// A "+N" popup that pops in, then rises and fades. Fire-and-forget: the
/// caller removes it from view state after GameConfig.Juice.scorePopupDuration.
struct FlyingScorePopupView: View {
    let text: String
    let tint: Color

    @State private var popped = false
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .offset(y: risen ? -50 : 0)
            .opacity(risen ? 0 : 1)
            .scaleEffect(popped ? 1.0 : 0.6)
            .onAppear {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    popped = true
                }
                withAnimation(.easeOut(duration: GameConfig.Juice.scorePopupDuration)) {
                    risen = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FlyingScorePopupView(text: "+18", tint: .green)
    }
}
