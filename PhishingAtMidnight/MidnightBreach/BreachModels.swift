import Foundation

/// The five systems on the map. Each has a fixed challenge type — the
/// specific packets/circuit/pattern are randomized per attempt, but which
/// *kind* of judgment a node trains never changes, so the map stays legible.
enum BreachNodeKind: String, CaseIterable, Hashable {
    case identity = "IDENTITY"
    case records = "RECORDS"
    case accessGate = "ACCESS GATE"
    case firewallCore = "FIREWALL CORE"
    case lifeSystem = "LIFE SYSTEM"

    var challengeKind: ChallengeKind {
        switch self {
        case .identity, .accessGate: return .accessLockdown
        case .records, .lifeSystem: return .packetIntercept
        case .firewallCore: return .firewallCircuit
        }
    }

    var symbolName: String {
        switch self {
        case .identity: return "person.badge.key.fill"
        case .records: return "doc.text.fill"
        case .accessGate: return "lock.shield.fill"
        case .firewallCore: return "flame.fill"
        case .lifeSystem: return "heart.text.square.fill"
        }
    }
}

/// The three visual challenge types a node can hand off to.
enum ChallengeKind: Equatable {
    case packetIntercept
    case firewallCircuit
    case accessLockdown
}
