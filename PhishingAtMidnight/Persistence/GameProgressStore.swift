import Foundation

/// Everything the game remembers between launches: best grade, best accuracy,
/// and how many runs have ever been completed (the ramp basis for difficulty —
/// see GameConfig.PoolComposition). Nothing more, per the brief.
@Observable
final class GameProgressStore {
    private enum Keys {
        static let totalReplays = "GameProgressStore.totalReplays"
        static let bestAccuracy = "GameProgressStore.bestAccuracy"
        static let bestGradeRaw = "GameProgressStore.bestGradeRaw"
    }

    private let defaults: UserDefaults

    private(set) var totalReplays: Int
    private(set) var bestAccuracy: Double
    private(set) var bestGrade: TriageEngine.Grade?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        totalReplays = defaults.integer(forKey: Keys.totalReplays)
        bestAccuracy = defaults.double(forKey: Keys.bestAccuracy)
        bestGrade = (defaults.string(forKey: Keys.bestGradeRaw)).flatMap(TriageEngine.Grade.init(rawValue:))
    }

    func recordRun(_ result: TriageEngine.RunResult) {
        totalReplays += 1
        defaults.set(totalReplays, forKey: Keys.totalReplays)

        if result.accuracy > bestAccuracy {
            bestAccuracy = result.accuracy
            defaults.set(bestAccuracy, forKey: Keys.bestAccuracy)
        }

        if rank(result.grade) > rank(bestGrade) {
            bestGrade = result.grade
            defaults.set(result.grade.rawValue, forKey: Keys.bestGradeRaw)
        }
    }

    private func rank(_ grade: TriageEngine.Grade?) -> Int {
        guard let grade else { return -1 }
        switch grade {
        case .gold: return 3
        case .silver: return 2
        case .bronze: return 1
        case .failed: return 0
        }
    }
}
