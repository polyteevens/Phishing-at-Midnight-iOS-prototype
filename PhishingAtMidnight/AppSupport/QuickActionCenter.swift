import Foundation

/// The one Home Screen Quick Action this app supports: long-press the app
/// icon to jump straight into a run.
enum QuickActionKind: String {
    case enterSystem = "com.become.phishingatmidnight.enterSystem"
}

/// A tiny relay between UIKit's AppDelegate/SceneDelegate (which receive the
/// quick-action tap) and SwiftUI (which acts on it). BreachStartView
/// observes `pendingAction` and clears it once handled.
@Observable
final class QuickActionCenter {
    static let shared = QuickActionCenter()
    var pendingAction: QuickActionKind?
    private init() {}
}
