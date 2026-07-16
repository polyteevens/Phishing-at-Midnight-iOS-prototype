import SwiftUI

@main
struct PhishingAtMidnightApp: App {
    var body: some Scene {
        WindowGroup {
            StartView()
                .preferredColorScheme(.dark)
        }
    }
}
