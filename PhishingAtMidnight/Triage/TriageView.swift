import SwiftUI

/// The playable core: an inbox feed driven by TriageEngine's tick loop, plus
/// an adaptive inspector (sheet on iPhone, side panel on iPad via `.inspector`)
/// for reading an email and making the Quarantine/Allow/Flag call.
struct TriageView: View {
    struct TeachingMoment: Identifiable {
        let id = UUID()
        let tell: String
        let wasCorrect: Bool
    }

    @State private var engine: TriageEngine
    @State private var selectedItemID: TriageEngine.InboxItem.ID?
    @State private var teaching: TeachingMoment?

    private let replayCount: Int
    private let onFinished: (TriageEngine.RunResult) -> Void

    init(pool: [Specimen], replayCount: Int, onFinished: @escaping (TriageEngine.RunResult) -> Void) {
        _engine = State(initialValue: TriageEngine(pool: pool))
        self.replayCount = replayCount
        self.onFinished = onFinished
    }

    private var selectedItem: TriageEngine.InboxItem? {
        guard let selectedItemID else { return nil }
        return engine.inbox.first { $0.id == selectedItemID }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { selectedItemID != nil },
            set: { isPresented in if !isPresented { selectedItemID = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                inboxList
            }
            .padding(16)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Night Shift — Triage")
            .navigationBarTitleDisplayMode(.inline)
        }
        .inspector(isPresented: inspectorBinding) {
            inspectorContent
        }
        .overlay(alignment: .top) { teachingBanner }
        .task { engine.startRun(replayCount: replayCount) }
        .onChange(of: engine.phase) { _, newPhase in
            if case .ended(let result) = newPhase {
                onFinished(result)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label(timeString(engine.timeRemaining), systemImage: "clock")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(engine.resolvedCount)/\(engine.totalToArrive) resolved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                BreachMeterView(value: engine.breachMeter)
                DisruptionMeterView(value: engine.disruptionMeter)
            }
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Inbox

    private var inboxList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(engine.inbox) { item in
                    InboxRowView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedItemID = item.id }
                }
            }
        }
        .overlay {
            if engine.inbox.isEmpty {
                ContentUnavailableView(
                    "Inbox clear",
                    systemImage: "tray",
                    description: Text("Waiting on the next message…")
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if let item = selectedItem {
            EmailInspectorView(item: item) { decision in
                handleDecision(item: item, decision: decision)
            }
            .id(item.id)
        } else {
            ContentUnavailableView("Select an email", systemImage: "envelope.open")
        }
    }

    private func handleDecision(item: TriageEngine.InboxItem, decision: TriageEngine.Decision) {
        let wasCorrect: Bool
        switch decision {
        case .quarantine: wasCorrect = item.specimen.isDangerous
        case .allow: wasCorrect = !item.specimen.isDangerous
        case .flag: wasCorrect = false
        }
        engine.decide(item.id, decision)
        selectedItemID = nil
        teaching = TeachingMoment(tell: item.specimen.tell, wasCorrect: wasCorrect)
    }

    // MARK: - Teaching moment banner

    @ViewBuilder
    private var teachingBanner: some View {
        if let teaching {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: teaching.wasCorrect ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(teaching.wasCorrect ? .green : .yellow)
                Text(teaching.tell)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: teaching.id) {
                try? await Task.sleep(for: .seconds(2.5))
                if self.teaching?.id == teaching.id {
                    self.teaching = nil
                }
            }
        }
    }
}

private struct InboxRowView: View {
    let item: TriageEngine.InboxItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.specimen.subject)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(item.displayName) · \(item.displayTimestamp)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.specimen.subject), from \(item.displayName), \(item.displayTimestamp)")
        .accessibilityHint("Double tap to inspect")
    }
}

#Preview("Triage — iPhone") {
    TriageView(pool: PreviewData.pool, replayCount: 0, onFinished: { _ in })
        .preferredColorScheme(.dark)
}

#Preview("Triage — iPad") {
    TriageView(pool: PreviewData.pool, replayCount: 3, onFinished: { _ in })
        .preferredColorScheme(.dark)
        .previewDevice("iPad Pro (11-inch) (4th generation)")
}
