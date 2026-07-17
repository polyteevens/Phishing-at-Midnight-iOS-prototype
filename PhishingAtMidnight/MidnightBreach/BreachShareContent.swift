import Foundation

/// Share text for the native Share Sheet (SwiftUI's `ShareLink`) — word-of-
/// mouth is the only marketing channel this prototype has. Deliberately no
/// URL: there's no App Store listing yet, and inventing one would be
/// misleading. Add a real link here once one exists.
enum BreachShareContent {
    static let inviteMessage = """
    I'm playing MIDNIGHT BREACH — a cyber defense tryout game. Attack pulses are heading for the core and I've got seconds to stop them. Think you'd hold the line better than me?
    """

    static func resultMessage(for result: SystemMapEngine.RunResult) -> String {
        let gradeText = result.grade == .failed ? "Failed" : "Grade \(result.grade.rawValue)"
        return """
        Just ran MIDNIGHT BREACH: \(gradeText) — Cyber Fit Signal: \(result.signal.rawValue). Think you can defend the core?
        """
    }
}
