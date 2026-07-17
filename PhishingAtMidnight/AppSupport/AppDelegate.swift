import UIKit

/// Bridges in just enough UIKit to register a Home Screen Quick Action —
/// SwiftUI's App/Scene lifecycle has no API for UIApplicationShortcutItem,
/// so this is the standard, minimal way to add one to an otherwise pure
/// SwiftUI app.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: QuickActionKind.enterSystem.rawValue,
                localizedTitle: "Enter System",
                localizedSubtitle: "Jump straight into a breach",
                icon: UIApplicationShortcutIcon(systemImageName: "bolt.shield.fill")
            )
        ]
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = BreachSceneDelegate.self
        return configuration
    }
}
