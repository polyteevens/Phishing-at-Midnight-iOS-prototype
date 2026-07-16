import SwiftUI

/// A number that counts up smoothly whenever its `value` changes under
/// `withAnimation` — used for the Results screen's stat reveal. Conforms to
/// `Animatable` directly (no wrapping modifier needed) so SwiftUI interpolates
/// `value` frame-by-frame and re-renders the formatted text as it climbs.
struct CountUpNumber: View, Animatable {
    var value: Double
    var format: (Int) -> String = { "\($0)" }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format(Int(value.rounded())))
    }
}

#Preview {
    CountUpNumber(value: 96, format: { "\($0)%" })
        .font(.largeTitle.bold())
        .foregroundStyle(.white)
        .padding()
        .background(Color.black)
}
