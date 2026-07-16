import SwiftUI

/// The inspection surface for a single inbox item: sender, subject, body,
/// an optional attachment, and an optional link whose true destination is
/// hidden until the player chooses to reveal it — mirroring how you'd
/// actually check a suspicious email. Ends with the Quarantine/Allow/Flag call.
struct EmailInspectorView: View {
    let item: TriageEngine.InboxItem
    let onDecide: (TriageEngine.Decision) -> Void

    @State private var domainRevealed = false
    @State private var linkRevealed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider().overlay(Color.white.opacity(0.15))
                bodyText
                if let attachment = item.specimen.attachmentName {
                    attachmentRow(attachment)
                }
                if let link = item.specimen.link {
                    linkRow(link)
                }
                Spacer(minLength: 12)
                decisionButtons
            }
            .padding(20)
        }
        .background { CinematicBackgroundView() }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.specimen.subject)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                Text("From:")
                    .foregroundStyle(.secondary)
                Text(item.displayName)
                    .foregroundStyle(.white)
            }
            .font(.subheadline)

            HStack(spacing: 6) {
                if domainRevealed {
                    Text(item.specimen.senderDomain)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { domainRevealed = true }
                    } label: {
                        Label("Inspect sender domain", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.weight(.semibold))
                }
            }
            .font(.subheadline)

            Text(item.displayTimestamp)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var bodyText: some View {
        Text(item.specimen.body)
            .font(.body)
            .foregroundStyle(.white.opacity(0.9))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func attachmentRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "paperclip")
                .foregroundStyle(.secondary)
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func linkRow(_ link: Specimen.Link) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text(link.claimedURL)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .underline()
                Spacer()
            }

            if linkRevealed {
                HStack(spacing: 10) {
                    Image(systemName: "eye")
                        .foregroundStyle(.secondary)
                    Text("Actually goes to: \(link.trueURL)")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { linkRevealed = true }
                } label: {
                    Label("Reveal true destination", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var decisionButtons: some View {
        VStack(spacing: 10) {
            decisionButton(title: "Quarantine", systemImage: "shield.slash.fill", tint: .red, decision: .quarantine)
            decisionButton(title: "Allow", systemImage: "checkmark.circle.fill", tint: .green, decision: .allow)
            decisionButton(title: "Flag for Review", systemImage: "flag.fill", tint: .yellow, decision: .flag)
        }
    }

    private func decisionButton(title: String, systemImage: String, tint: Color, decision: TriageEngine.Decision) -> some View {
        Button {
            onDecide(decision)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

#Preview("Inspector — dangerous") {
    EmailInspectorView(
        item: PreviewData.inboxItem(id: "it-password-fake"),
        onDecide: { _ in }
    )
    .preferredColorScheme(.dark)
}

#Preview("Inspector — legit") {
    EmailInspectorView(
        item: PreviewData.inboxItem(id: "lab-results-real"),
        onDecide: { _ in }
    )
    .preferredColorScheme(.dark)
}
