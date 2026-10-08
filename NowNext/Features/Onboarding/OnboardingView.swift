import SwiftUI

/// Three quick cards, skippable. Gets people to the Brain Dump fast.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(Router.self) private var router
    @State private var page = 0

    private struct Card: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let cards: [Card] = [
        Card(id: 0, symbol: "tray.and.arrow.down.fill",
             title: "Dump it all out",
             text: "Get every task and worry out of your head. Paste a list and each line becomes a task. Sort later."),
        Card(id: 1, symbol: "bolt.fill",
             title: "Pick three for Now",
             text: "Now holds up to three things. Everything else waits in Next or Later, out of the way."),
        Card(id: 2, symbol: "timer",
             title: "Tiny steps. Visible time.",
             text: "Break big tasks into silly-small steps, guess the time, then watch it shrink on a visual timer."),
    ]

    private var isLast: Bool { page >= cards.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            ProgressRail(filled: page + 1, total: cards.count,
                         label: String(localized: "Step \(page + 1) of \(cards.count)"))
                .frame(maxWidth: .infinity)
                .frame(height: Theme.minTap)
                .padding(.top, 8)

            TabView(selection: $page) {
                ForEach(cards) { card in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.spacingM) {
                            if card.id == 0 {
                                BrandLockup(badgeSize: 110)
                                    .padding(.vertical, Theme.spacingM)
                            } else {
                                ShieldBadge(size: 72)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.spacingM)
                            }
                            HStack(spacing: 12) {
                                IconTile(symbol: card.symbol, color: card.symbol == "bolt.fill" ? Theme.yellow : Theme.red)
                                Text(card.title)
                                    .themeFont(.screenTitle)
                                    .foregroundStyle(Theme.text)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            Text(card.text)
                                .themeFont(.body)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            if card.id == cards.count - 1 {
                                Callout(symbol: "exclamationmark.shield.fill", title: "Heads up", message: LocalizedStringKey(Disclaimer.text))
                            }
                        }
                        .padding(.horizontal, Theme.gutter)
                    }
                    .tag(card.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .sensoryFeedback(.selection, trigger: page)

            BottomActionBar {
                Button("Skip") { finish(goToBrainDump: false) }
                    .buttonStyle(.secondary)
                Button {
                    if isLast {
                        finish(goToBrainDump: true)
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(isLast ? LocalizedStringKey("Start my dump") : LocalizedStringKey("Next"))
                }
                .buttonStyle(.primary)
                .layoutPriority(1)
            }
        }
        .screenBackground()
    }

    private func finish(goToBrainDump: Bool) {
        if goToBrainDump { router.tab = .brainDump }
        onFinish()
    }
}
