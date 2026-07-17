import UIKit

/// Catches a Quick Action tap on both paths: a cold launch (the shortcut
/// arrives in `connectionOptions`) and a warm one (the app was already
/// running, so `performActionFor` fires instead). Either way it just hands
/// the kind off to QuickActionCenter for SwiftUI to act on.
final class BreachSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let shortcutItem = connectionOptions.shortcutItem,
           let kind = QuickActionKind(rawValue: shortcutItem.type) {
            QuickActionCenter.shared.pendingAction = kind
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        if let kind = QuickActionKind(rawValue: shortcutItem.type) {
            QuickActionCenter.shared.pendingAction = kind
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
}
