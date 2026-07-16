import SwiftUI

/// Classic decaying-oscillation screen shake: drive `trigger` up by one on
/// every shake-worthy moment and the view rattles and settles.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

extension View {
    /// Increment `trigger` (an Int counter) to fire one shake.
    func shake(trigger: Int, amount: CGFloat = 8) -> some View {
        modifier(ShakeEffect(amount: amount, animatableData: CGFloat(trigger)))
            .animation(.linear(duration: GameConfig.Juice.shakeDuration), value: trigger)
    }
}
