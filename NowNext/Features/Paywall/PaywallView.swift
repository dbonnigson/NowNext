import StoreKit
import SwiftUI

/// One-time unlock. Clear price, clear contents, Restore always visible.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.text)
                        .frame(width: Theme.minTap, height: Theme.minTap)
                        .background(Circle().fill(Theme.surfaceRaised))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    ShieldBadge(size: 80)
                        .frame(maxWidth: .infinity)
                    Text("NowNext Pro")
                        .themeFont(.heroTitle)
                        .foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pay once. Yours forever. No subscription.")
                        .themeFont(.bodyStrong)
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)

                    SectionLabel("What you get")
                    feature("hourglass", "Upcoming, as a countdown", "Your calendar shown as time left (45 min, 3 days, 2 weeks), not another grid of dates.")
                    feature("repeat", "Routines", "Tasks that come back on their own. Missed days never pile up.")
                    feature("chart.bar.fill", "Insights", "Focus by day, plus how your time guesses compare with reality.")
                    feature("heart.fill", "Support an indie app", "Keeps NowNext ad-free, account-free and private.")

                    Text("Everything else stays free: Brain Dump, Today, Tiny Steps, the focus timer, widgets and Live Activities.")
                        .themeFont(.detail)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)

                    if purchases.isPro {
                        Callout(symbol: "checkmark.seal.fill", title: "Unlocked", message: "Pro is unlocked. Thank you!")
                    } else {
                        Text(priceLine)
                            .themeFont(.detail)
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 4)
                    }

                    HStack(spacing: Theme.spacingL) {
                        Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                        Link("Terms of Use", destination: AppLinks.termsOfUse)
                    }
                    .themeFont(.detail)
                    .foregroundStyle(Theme.text)
                    .underline()
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.spacingS)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, Theme.spacingL)
            }

            if !purchases.isPro {
                BottomActionBar {
                    Button("Restore") {
                        Task { await purchases.restore() }
                    }
                    .buttonStyle(.secondary)
                    .disabled(purchases.isWorking)

                    Button {
                        Task { await purchases.purchase() }
                    } label: {
                        if purchases.isWorking {
                            ProgressView().tint(Theme.text)
                        } else if let product = purchases.product {
                            Text("Unlock \(product.displayPrice)")
                        } else {
                            Text("Unlock Pro")
                        }
                    }
                    .buttonStyle(.primary)
                    .layoutPriority(1)
                    .disabled(purchases.isWorking)
                }
            }
        }
        .screenBackground()
        .alert(
            "Purchase",
            isPresented: Binding(get: { purchases.errorMessage != nil }, set: { if !$0 { purchases.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.errorMessage ?? "")
        }
        .task {
            if purchases.product == nil { await purchases.loadProduct() }
        }
    }

    private var priceLine: String {
        if let product = purchases.product {
            return String(localized: "\(product.displayPrice), one-time purchase.")
        }
        return String(localized: "Loading price from the App Store…")
    }

    private func feature(_ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: Theme.red)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .themeFont(.optionTitle)
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .themeFont(.detail)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: Theme.optionRowMinHeight)
        .themeCard()
        .accessibilityElement(children: .combine)
    }
}
