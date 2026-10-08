import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen + Dynamic Island countdown for the active focus session.
struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenFocusView(title: context.attributes.taskTitle, state: context.state)
                .padding()
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Focus", systemImage: "timer")
                        .font(.system(size: 15, weight: .black))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RemainingText(state: context.state)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !context.attributes.taskTitle.isEmpty {
                            Text(context.attributes.taskTitle)
                                .font(.subheadline)
                                .lineLimit(1)
                        }
                        FocusProgressBar(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(Theme.red)
            } compactTrailing: {
                RemainingText(state: context.state)
                    .monospacedDigit()
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Theme.red)
            }
        }
    }
}

private struct LockScreenFocusView: View {
    let title: String
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.isPaused ? LocalizedStringKey("Paused") : LocalizedStringKey("Focusing"), systemImage: state.isPaused ? "pause.fill" : "timer")
                    .font(.system(size: 15, weight: .black))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.red)
                Spacer()
                RemainingText(state: state)
                    .font(.system(size: 26, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)
            }
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }
            FocusProgressBar(state: state)
        }
    }
}

private struct RemainingText: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        if let end = state.endDate {
            Text(timerInterval: Date()...max(end, Date()), countsDown: true)
                .multilineTextAlignment(.trailing)
        } else {
            Text(Duration.seconds(state.pausedRemaining).formatted(.time(pattern: .minuteSecond)))
        }
    }
}

private struct FocusProgressBar: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        if let range = state.displayRange {
            ProgressView(timerInterval: range, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Theme.red)
        } else {
            ProgressView(value: state.pausedFractionRemaining)
                .tint(Theme.gray)
        }
    }
}
