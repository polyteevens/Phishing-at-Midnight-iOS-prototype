import SwiftUI

/// The visual network map: five nodes arranged around a glowing core, red
/// attack pulses traveling inward along the connection lines, and tappable
/// node buttons that light up while threatened. All the actual game state
/// comes from SystemMapEngine — this view only draws it and forwards taps.
struct SystemMapView: View {
    let engine: SystemMapEngine
    let onTapNode: (BreachNodeKind) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.36
            let positions = Self.nodePositions(center: center, radius: radius)

            ZStack {
                Canvas { context, _ in
                    // Core glow
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52)),
                        with: .radialGradient(
                            Gradient(colors: [Color.cyan.opacity(0.85), .clear]),
                            center: center, startRadius: 0, endRadius: 52
                        )
                    )

                    for node in engine.nodes {
                        guard let pos = positions[node.id] else { continue }

                        var line = Path()
                        line.move(to: pos)
                        line.addLine(to: center)
                        context.stroke(
                            line,
                            with: .color(.white.opacity(node.state == .threatened ? 0.22 : 0.1)),
                            lineWidth: 2
                        )

                        if node.state == .threatened {
                            let t = node.pulseProgress
                            let pulsePoint = CGPoint(
                                x: pos.x + (center.x - pos.x) * t,
                                y: pos.y + (center.y - pos.y) * t
                            )
                            context.fill(
                                Path(ellipseIn: CGRect(x: pulsePoint.x - 7, y: pulsePoint.y - 7, width: 14, height: 14)),
                                with: .color(.red)
                            )
                            context.fill(
                                Path(ellipseIn: CGRect(x: pulsePoint.x - 12, y: pulsePoint.y - 12, width: 24, height: 24)),
                                with: .radialGradient(
                                    Gradient(colors: [Color.red.opacity(0.5), .clear]),
                                    center: pulsePoint, startRadius: 0, endRadius: 12
                                )
                            )
                        }
                    }
                }

                ForEach(engine.nodes) { node in
                    if let pos = positions[node.id] {
                        NodeButtonView(node: node) { onTapNode(node.id) }
                            .position(pos)
                    }
                }

                Text("CORE")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.cyan)
                    .position(x: center.x, y: center.y + 30)
            }
        }
    }

    private static func nodePositions(center: CGPoint, radius: CGFloat) -> [BreachNodeKind: CGPoint] {
        var result: [BreachNodeKind: CGPoint] = [:]
        let kinds = BreachNodeKind.allCases
        for (index, kind) in kinds.enumerated() {
            let angle = (Double(index) / Double(kinds.count)) * 2 * .pi - .pi / 2
            result[kind] = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        return result
    }
}

private struct NodeButtonView: View {
    let node: SystemMapEngine.Node
    let onTap: () -> Void

    private var tint: Color {
        switch node.state {
        case .safe: .cyan
        case .threatened: .red
        case .inChallenge: .orange
        case .secured: .green
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.22))
                        .overlay(Circle().stroke(tint, lineWidth: 2))
                    Image(systemName: node.id.symbolName)
                        .font(.system(size: 18))
                        .foregroundStyle(tint)
                }
                .frame(width: 54, height: 54)
                .scaleEffect(node.state == .threatened ? 1.08 : 1.0)

                Text(node.id.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .buttonStyle(.plain)
        .disabled(node.state != .threatened)
        .animation(.easeInOut(duration: 0.3), value: node.state)
        .accessibilityLabel("\(node.id.rawValue), \(accessibilityStateDescription)")
    }

    private var accessibilityStateDescription: String {
        switch node.state {
        case .safe: "secure"
        case .threatened: "under attack, double tap to defend"
        case .inChallenge: "defending"
        case .secured: "just secured"
        }
    }
}

#Preview {
    let engine = SystemMapEngine()
    return ZStack {
        Color.black.ignoresSafeArea()
        SystemMapView(engine: engine, onTapNode: { _ in })
    }
    .onAppear { engine.start() }
    .preferredColorScheme(.dark)
}
