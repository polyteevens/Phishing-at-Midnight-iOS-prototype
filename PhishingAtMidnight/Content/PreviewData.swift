import Foundation

/// Preview-only convenience for loading the real specimen pool and building
/// one-off InboxItems, so #Preview blocks across the app can share sample data
/// instead of hand-rolling fixtures. Never referenced by shipping game logic.
enum PreviewData {
    static let pool: [Specimen] = {
        do {
            return try SpecimenLoader.loadPool()
        } catch {
            fatalError("PreviewData failed to load specimens.json: \(error)")
        }
    }()

    static func specimen(id: String) -> Specimen {
        guard let match = pool.first(where: { $0.id == id }) else {
            fatalError("PreviewData: no specimen with id \(id)")
        }
        return match
    }

    static func inboxItem(
        id: String,
        arrivalTime: TimeInterval = 0,
        clickDeadline: TimeInterval? = nil
    ) -> TriageEngine.InboxItem {
        let specimen = specimen(id: id)
        return TriageEngine.InboxItem(
            id: specimen.id,
            specimen: specimen,
            displayName: specimen.senderDisplayNames.first ?? "Unknown Sender",
            displayTimestamp: "12:14 AM",
            arrivalTime: arrivalTime,
            clickDeadline: clickDeadline
        )
    }
}
