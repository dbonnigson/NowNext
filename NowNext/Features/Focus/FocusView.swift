import SwiftData
import SwiftUI

/// Visual focus timer. One task, one block of time, one next step on screen.
struct FocusView: View {
    @Environment(\.modelContext) private var context
    @Environment(FocusController.self) private var focus
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<TaskItem> { $0.completedAt == nil }, sort: \TaskItem.sortIndex)
    private var openTasks: [TaskItem]

    @State private var selectedTaskID: UUID?
    @State private var minutes = 25
    @State private var confirmStop = false

    private static let presets = [5, 10, 15, 25, 45]

    private var candidates: [TaskItem] {
        openTasks.filter { $0.slot == .now } + openTasks.filter { $0.slot == .next }
    }

    private func task(for id: UUID?) -> TaskItem? {
        guard let id else { return nil }
        return openTasks.first { $0.uuid == id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    if let session = focus.session {
                        ActiveFocusPanel(session: session, task: task(for: session.taskID))
                    } else if let summary = focus.lastSummary {
                        summaryPanel(summary)
                    } else {
                        setupPanel
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, Theme.spacingL)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .themedNavigationBar()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if let session = focus.session {
                        FocusRail(session: session)
                    } else {
                        NowRail()
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .onAppear(perform: applyCandidate)
            .onChange(of: router.focusCandidateID) { _, _ in applyCandidate() }
            .confirmationDialog("End this session?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("End and save my time") { focus.stop(context: context) }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("The time you've focused so far still counts.")
            }
        }
    }

    private func applyCandidate() {
        guard let id = router.focusCandidateID else { return }
        router.focusCandidateID = nil
        guard !focus.isActive else { return }
        focus.lastSummary = nil
        selectedTaskID = id
        if let est = task(for: id)?.estimateMinutes {
            minutes = min(max(est, 5), 90)
        }
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let session = focus.session {
            BottomActionBar {
                Button("End") { confirmStop = true }
                    .buttonStyle(.secondary)
                if session.clock.isRunning {
                    Button { focus.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                        .buttonStyle(.primary)
                        .layoutPriority(1)
                } else {
                    Button { focus.resume() } label: { Label("Resume", systemImage: "play.fill") }
                        .buttonStyle(.primary)
                        .layoutPriority(1)
                }
            }
        } else if let summary = focus.lastSummary {
            let t = task(for: summary.taskID)
            BottomActionBar {
                Button("Take a break") { focus.lastSummary = nil }
                    .buttonStyle(.secondary)
                if let t {
                    Button("Mark done") {
                        TaskStore.setDone(t, true, context: context)
                        focus.lastSummary = nil
                    }
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                } else {
                    Button("5 more min") { focus.start(minutes: 5, task: nil) }
                        .buttonStyle(.primary)
                        .layoutPriority(1)
                }
            }
        } else {
            BottomActionBar {
                Button {
                    focus.start(minutes: minutes, task: task(for: selectedTaskID))
                } label: {
                    Label(String(localized: "Start \(minutes)-min focus"), systemImage: "play.fill")
                }
                .buttonStyle(.primary)
            }
        }
    }

    // MARK: Setup

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            ScreenTitle("Focus")

            SectionLabel("Working on")
            Menu {
                Button("Just focus (no task)") { selectedTaskID = nil }
                ForEach(candidates) { t in
                    Button(t.title) { selectedTaskID = t.uuid }
                }
            } label: {
                OptionRow(
                    title: task(for: selectedTaskID)?.title ?? String(localized: "Just focus (no task)"),
                    detail: firstStepText,
                    showsChevron: false
                ) {
                    IconTile(symbol: "scope", color: Theme.red)
                }
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .themeCard()
            }
            .sensoryFeedback(.selection, trigger: selectedTaskID)

            if candidates.isEmpty {
                Text("Put something in Now or Next to focus on it here.")
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
            }

            SectionLabel("How long")
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.self) { p in
                    SelectTile(title: DurationText.short(minutes: p), isSelected: minutes == p) {
                        minutes = p
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: minutes)

            HStack(spacing: 12) {
                roundButton("minus", label: "Less time") { minutes = max(1, minutes - 1) }
                Text("\(minutes) min")
                    .themeFont(.statNumber)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                roundButton("plus", label: "More time") { minutes = min(120, minutes + 1) }
            }
            .padding(.vertical, 6)

            if let est = task(for: selectedTaskID)?.estimateMinutes {
                Chip(text: String(localized: "Your guess: \(DurationText.short(minutes: est))"), symbol: "hourglass")
            }

            VisualTimerView(fractionRemaining: 1, color: Theme.red)
                .frame(maxWidth: 200)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingS)

            Text("Short is fine. Starting is the hard part.")
                .themeFont(.detail)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private var firstStepText: String? {
        guard let step = task(for: selectedTaskID)?.nextOpenStep else { return nil }
        return String(localized: "First step: \(step.title)")
    }

    private func roundButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Theme.surfaceRaised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Summary

    private func summaryPanel(_ summary: FocusController.Summary) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingM) {
            ShieldBadge(size: 72)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.spacingL)
            Text("Nice. That counts.")
                .themeFont(.heroTitle)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            StatTile(value: DurationText.short(seconds: summary.focusedSeconds), label: String(localized: "Focused this session"))
            if !summary.taskTitle.isEmpty {
                Chip(text: summary.taskTitle, symbol: "scope", symbolColor: Theme.red)
            }
            Button {
                focus.start(minutes: 5, task: task(for: summary.taskID))
            } label: {
                Label("Keep going: 5 more minutes", systemImage: "goforward.5")
            }
            .buttonStyle(.secondary)
        }
        .sensoryFeedback(.success, trigger: summary.focusedSeconds)
    }
}

/// Rail in the nav bar while a session runs: 10 bars of elapsed time.
private struct FocusRail: View {
    let session: FocusController.ActiveSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let progress = session.clock.progress(at: timeline.date)
            ProgressRail(
                filled: Int((progress * 10).rounded(.down)),
                total: 10,
                label: String(localized: "\(session.clock.remaining(at: timeline.date).clockString) left")
            )
        }
    }
}

/// The running / paused timer.
private struct ActiveFocusPanel: View {
    let session: FocusController.ActiveSession
    let task: TaskItem?

    @Environment(\.modelContext) private var context
    @Environment(FocusController.self) private var focus

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let remaining = session.clock.remaining(at: now)
            let fraction = 1 - session.clock.progress(at: now)

            VStack(spacing: Theme.spacingM) {
                SectionLabel(session.clock.isRunning ? LocalizedStringKey("Focusing") : LocalizedStringKey("Paused"))
                if !session.taskTitle.isEmpty {
                    Text(session.taskTitle)
                        .themeFont(.cardTitle)
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(3)
                        .accessibilityAddTraits(.isHeader)
                }

                VisualTimerView(fractionRemaining: fraction, color: session.clock.isRunning ? Theme.red : Theme.gray)
                    .frame(maxWidth: 300)
                    .animation(.linear(duration: 1), value: fraction)

                Text(remaining.clockString)
                    .themeFont(.timer)
                    .foregroundStyle(Theme.text)
                    .accessibilityLabel(Text("\(Int(remaining / 60)) minutes \(Int(remaining) % 60) seconds remaining"))

                if let task, let step = task.nextOpenStep {
                    HStack(spacing: 12) {
                        PlateCheck(isDone: false) {
                            withAnimation { TaskStore.toggleStep(step, context: context) }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next step")
                                .themeFont(.sectionLabel)
                                .foregroundStyle(Theme.muted)
                            Text(step.title)
                                .themeFont(.optionTitle)
                                .foregroundStyle(Theme.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(minHeight: Theme.optionRowMinHeight)
                    .themeCard()
                }

                Button {
                    focus.extend(minutes: 5)
                } label: {
                    Label("Add 5 minutes", systemImage: "plus")
                }
                .buttonStyle(.secondary)
            }
        }
    }
}
