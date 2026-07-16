import SwiftUI

/// The playable core: an inbox feed driven by TriageEngine's tick loop, plus
/// an adaptive inspector (sheet on iPhone, side panel on iPad via `.inspector`)
/// for reading an email and making the Quarantine/Allow/Flag call. This view
/// also owns all the "juice" — every decision here pays back with motion,
/// sound, and haptics; TriageEngine only ever supplies the signal.
struct TriageView: View {
    struct TeachingMoment: Identifiable {
        let id = UUID()
        let tell: String
        let wasCorrect: Bool
    }

    private struct BurstEvent: Identifiable {
        let id = UUID()
        let color: Color
    }

    private struct ScorePopup: Identifiable {
        let id = UUID()
        let text: String
    }

    private struct StampEvent: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let tint: Color
    }

    @State private var engine: TriageEngine
    @State private var haptics = HapticsAudioService()

    @State private var selectedItemID: TriageEngine.InboxItem.ID?
    @State private var teaching: TeachingMoment?

    @State private var burstEvents: [BurstEvent] = []
    @State private var scorePopups: [ScorePopup] = []
    @State private var activeStamp: StampEvent?
    @State private var shakeTrigger = 0
    @State private var flashOpacity: Double = 0
    @State private var showRareEventBanner = false

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
        .overlay { TensionOverlayView(state: engine.tensionState) }
        .overlay(alignment: .top) { teachingBanner }
        .overlay(alignment: .center) { burstAndPopupLayer }
        .overlay(alignment: .top) { rareEventBanner }
        .overlay { Color.red.opacity(flashOpacity).allowsHitTesting(false).ignoresSafeArea() }
        .shake(trigger: shakeTrigger)
        .sensoryFeedback(trigger: teaching?.id) { _, _ in
            teaching.map { $0.wasCorrect ? .success : .warning }
        }
        .task {
            engine.startRun(replayCount: replayCount)
            haptics.playAmbient()
        }
        .onChange(of: engine.breachMeter) { _, _ in updateMeterDrivenAudio() }
        .onChange(of: engine.disruptionMeter) { _, _ in updateMeterDrivenAudio() }
        .onChange(of: engine.criticalEnteredToken) { _, token in
            guard token > 0 else { return }
            shakeTrigger += 1
        }
        .onChange(of: engine.rareEventTriggerToken) { _, token in
            guard token > 0 else { return }
            haptics.playRareEventStart()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showRareEventBanner = true }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut(duration: 0.3)) { showRareEventBanner = false }
            }
        }
        .onChange(of: engine.lastFeedback) { _, feedback in
            guard let feedback else { return }
            handleFeedback(feedback)
        }
        .onChange(of: engine.phase) { _, newPhase in
            if case .ended(let result) = newPhase {
                haptics.stopAmbient()
                haptics.stopTension()
                haptics.stopHeartbeat()
                haptics.missionEndBeat(outcome: result.outcome)
                onFinished(result)
            }
        }
        .onDisappear {
            haptics.stopAmbient()
            haptics.stopTension()
            haptics.stopHeartbeat()
        }
    }

    private func updateMeterDrivenAudio() {
        haptics.updateTension(breach: engine.breachMeter, disruption: engine.disruptionMeter)
        haptics.updateAmbientIntensity(for: engine.tensionState)
        haptics.updateHeartbeat(worstMeter: max(engine.breachMeter, engine.disruptionMeter))
    }

    // MARK: - Feedback -> juice

    private func handleFeedback(_ feedback: TriageEngine.DecisionFeedback) {
        switch feedback.kind {
        case .confidentCorrect:
            haptics.playCorrectCall(comboMultiplier: feedback.comboMultiplier)

            let burst = BurstEvent(color: feedback.decision == .quarantine ? .red : .green)
            burstEvents.append(burst)
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                burstEvents.removeAll { $0.id == burst.id }
            }

            if feedback.pointsEarned >= 1 {
                let popup = ScorePopup(text: "+\(Int(feedback.pointsEarned.rounded()))")
                scorePopups.append(popup)
                Task {
                    try? await Task.sleep(for: .seconds(GameConfig.Juice.scorePopupDuration))
                    scorePopups.removeAll { $0.id == popup.id }
                }
            }

        case .mistakeBreach, .mistakeDisruption:
            haptics.playMistake()
            shakeTrigger += 1
            withAnimation(.easeIn(duration: 0.05)) { flashOpacity = 0.32 }
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) { flashOpacity = 0 }

            let stamp = StampEvent(
                text: feedback.kind == .mistakeBreach ? "CLICKED" : "FRIENDLY FIRE",
                tint: feedback.kind == .mistakeBreach ? .red : .orange
            )
            activeStamp = stamp
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                if activeStamp?.id == stamp.id { activeStamp = nil }
            }

        case .flagged:
            if feedback.brokenStreak > 0 {
                haptics.playComboBreak()
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
                if engine.comboStreak >= 2 {
                    ComboBadgeView(streak: engine.comboStreak, multiplier: engine.comboMultiplier)
                        .transition(.scale.combined(with: .opacity))
                }
                Text("\(engine.resolvedCount)/\(engine.totalToArrive) resolved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: engine.comboStreak >= 2)
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
                    Button {
                        selectedItemID = item.id
                    } label: {
                        InboxRowView(item: item)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: engine.inbox.map(\.id))
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

    // MARK: - Rare event banner

    @ViewBuilder
    private var rareEventBanner: some View {
        if showRareEventBanner {
            HStack(spacing: 8) {
                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                Text("COORDINATED ATTACK")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red, in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Burst / stamp / popup layer

    @ViewBuilder
    private var burstAndPopupLayer: some View {
        ZStack {
            ForEach(burstEvents) { burst in
                ParticleBurstView(color: burst.color)
                    .frame(width: 160, height: 160)
                    .id(burst.id)
            }
            ForEach(scorePopups) { popup in
                FlyingScorePopupView(text: popup.text, tint: .white)
                    .id(popup.id)
            }
            if let activeStamp {
                StampView(text: activeStamp.text, tint: activeStamp.tint)
                    .id(activeStamp.id)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct InboxRowView: View {
    let item: TriageEngine.InboxItem

    @State private var justArrived = true

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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(justArrived ? 0.7 : 0), lineWidth: 2)
        )
        .scaleEffect(justArrived ? 1.03 : 1.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                justArrived = false
            }
        }
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
