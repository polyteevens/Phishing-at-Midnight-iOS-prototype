import SwiftUI

/// A short-lived radial particle burst for a satisfying "catch" moment.
/// Give it a fresh `.id()` per burst — its particle paths are randomized
/// once at init and don't change on re-render.
struct ParticleBurstView: View {
    let color: Color

    private let particles: [Particle]
    private let startDate = Date()
    private let lifetime: TimeInterval = 0.55

    private struct Particle {
        let angle: Double
        let speed: Double
        let size: Double
    }

    init(color: Color, particleCount: Int = 14) {
        self.color = color
        self.particles = (0..<particleCount).map { _ in
            Particle(
                angle: Double.random(in: 0..<(2 * .pi)),
                speed: Double.random(in: 70...170),
                size: Double.random(in: 4...9)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                guard elapsed < lifetime else { return }
                let fade = 1 - (elapsed / lifetime)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                for particle in particles {
                    let distance = particle.speed * elapsed
                    let point = CGPoint(
                        x: center.x + cos(particle.angle) * distance,
                        y: center.y + sin(particle.angle) * distance
                    )
                    let rect = CGRect(
                        x: point.x - particle.size / 2,
                        y: point.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    context.opacity = fade
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ParticleBurstView(color: .green)
        .frame(width: 200, height: 200)
        .background(Color.black)
}
