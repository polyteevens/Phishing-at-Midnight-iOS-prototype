import Foundation

/// A single authored email in the specimen pool. Specimens are pure data —
/// see `specimens.json`. Adding or rebalancing an email never requires
/// touching Swift code.
struct Specimen: Identifiable, Codable, Hashable {
    struct Link: Codable, Hashable {
        /// What the link text/preview claims to point to.
        let claimedURL: String
        /// Where the link actually goes. Revealed on inspection.
        let trueURL: String
    }

    enum Difficulty: String, Codable, Hashable {
        case normal
        case hard
    }

    let id: String
    let isDangerous: Bool
    /// Small pool of display-name variants; the engine picks one per run
    /// so the same specimen doesn't look identical every time.
    let senderDisplayNames: [String]
    let senderDomain: String
    let subject: String
    let body: String
    let link: Link?
    let attachmentName: String?
    /// Shown in the post-decision teaching moment: why this is dangerous,
    /// or why it's legitimate-but-weird.
    let tell: String
    /// Groups a dangerous specimen with its legitimate "twin" on the same
    /// topic, so pool sampling can pair or ramp them deliberately.
    let twinGroup: String
    let difficulty: Difficulty
}
