import SwiftUI
import StoreKit

struct PaywallView: View {
    let trigger: PaywallTrigger
    let language: String
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: PaywallPlan = .yearly

    init(
        trigger: PaywallTrigger = .general,
        language: String = (UserDefaults.standard.string(forKey: "appLanguage") ?? "de"),
        subscriptionManager: SubscriptionManager = .shared
    ) {
        self.trigger = trigger
        self.language = language
        self.subscriptionManager = subscriptionManager
    }

    var body: some View {
        ZStack {
            Color.klunaBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: KlunaSpacing.lg) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.klunaMuted)
                                .frame(width: 32, height: 32)
                                .background(Color.klunaSurface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, KlunaSpacing.md)

                    VStack(spacing: KlunaSpacing.sm) {
                        Text(trigger.headline(language: language))
                            .font(KlunaFont.heading(26))
                            .foregroundColor(.klunaPrimary)
                            .multilineTextAlignment(.center)
                        Text(trigger.subheadline(language: language))
                            .font(KlunaFont.body(16))
                            .foregroundColor(.klunaSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, KlunaSpacing.lg)

                    VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                        PaywallFeatureRow(icon: "infinity", text: language == "de" ? "Unlimitierte Sessions" : "Unlimited sessions", highlight: trigger == .sessionLimit)
                        PaywallFeatureRow(icon: "chart.bar.fill", text: language == "de" ? "Alle 6 Dimensionen" : "All 6 dimensions", highlight: trigger == .dimensionLocked)
                        PaywallFeatureRow(icon: "play.fill", text: language == "de" ? "Audio-Playback mit Heatmap" : "Audio playback with heatmap", highlight: trigger == .playbackLocked)
                        PaywallFeatureRow(icon: "person.fill.checkmark", text: language == "de" ? "KI Coach-Modus" : "AI coach mode", highlight: trigger == .coachModeLocked)
                        PaywallFeatureRow(icon: "target", text: language == "de" ? "Gezielte Micro-Drills" : "Targeted micro-drills", highlight: false)
                        PaywallFeatureRow(icon: "trophy.fill", text: language == "de" ? "Personal Best und Milestones" : "Personal best and milestones", highlight: false)
                        PaywallFeatureRow(icon: "waveform", text: language == "de" ? "Stimm-Journal" : "Voice journal", highlight: false)
                        PaywallFeatureRow(icon: "star.fill", text: language == "de" ? "Alle 15 Challenge-Level" : "All 15 challenge levels", highlight: trigger == .challengeLevelLocked)
                    }
                    .padding(KlunaSpacing.md)
                    .background(Color.klunaSurface)
                    .cornerRadius(KlunaRadius.card)
                    .padding(.horizontal, KlunaSpacing.md)

                    VStack(spacing: KlunaSpacing.sm) {
                        PlanOption(
                            plan: .yearly,
                            isSelected: selectedPlan == .yearly,
                            price: yearlyProduct?.displayPrice ?? "EUR 149.99",
                            perMonth: language == "de" ? "EUR 12.50/Monat" : "EUR 12.50/month",
                            badge: language == "de" ? "Spare 37%" : "Save 37%",
                            language: language,
                            onSelect: { selectedPlan = .yearly }
                        )
                        PlanOption(
                            plan: .monthly,
                            isSelected: selectedPlan == .monthly,
                            price: monthlyProduct?.displayPrice ?? "EUR 19.99",
                            perMonth: language == "de" ? "EUR 19.99/Monat" : "EUR 19.99/month",
                            badge: nil,
                            language: language,
                            onSelect: { selectedPlan = .monthly }
                        )
                    }
                    .padding(.horizontal, KlunaSpacing.md)

                    Button(action: purchase) {
                        if subscriptionManager.purchaseInProgress {
                            ProgressView().tint(.white)
                        } else {
                            Text(L10n.startKlunaPro)
                                .font(KlunaFont.heading(18))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KlunaSpacing.md + 2)
                    .background(Color.klunaAccent)
                    .cornerRadius(KlunaRadius.button)
                    .padding(.horizontal, KlunaSpacing.md)
                    .disabled(subscriptionManager.purchaseInProgress)

                    VStack(spacing: 4) {
                        Button(action: { Task { await subscriptionManager.restorePurchases() } }) {
                            Text(L10n.restorePurchases)
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaMuted)
                        }
                        Text(language == "de"
                             ? "Jederzeit kuendbar. Es gelten AGB und Datenschutz."
                             : "Cancel anytime. Terms and privacy policy apply.")
                        .font(KlunaFont.caption(10))
                        .foregroundColor(.klunaMuted.opacity(0.6))
                        .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, KlunaSpacing.xl)
                }
            }
        }
        .task { await subscriptionManager.loadProducts() }
    }

    private var monthlyProduct: Product? {
        subscriptionManager.products.first(where: { $0.id == SubscriptionManager.monthlyProductID })
    }

    private var yearlyProduct: Product? {
        subscriptionManager.products.first(where: { $0.id == SubscriptionManager.yearlyProductID })
    }

    private func purchase() {
        Task {
            let selected = selectedPlan == .yearly ? yearlyProduct : monthlyProduct
            guard let selected else { return }
            let success = try? await subscriptionManager.purchase(selected)
            if success == true {
                dismiss()
            }
        }
    }
}

struct PaywallFeatureRow: View {
    let icon: String
    let text: String
    let highlight: Bool

    var body: some View {
        HStack(spacing: KlunaSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(highlight ? .klunaAccent : .klunaGreen)
                .frame(width: 24)
            Text(text)
                .font(KlunaFont.body(14))
                .foregroundColor(highlight ? .klunaPrimary : .klunaSecondary)
            Spacer()
            if highlight {
                Text("★")
                    .font(.system(size: 10))
                    .foregroundColor(.klunaAccent)
            }
        }
    }
}

enum PaywallPlan {
    case monthly
    case yearly
}

struct PlanOption: View {
    let plan: PaywallPlan
    let isSelected: Bool
    let price: String
    let perMonth: String
    let badge: String?
    let language: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .stroke(isSelected ? Color.klunaAccent : Color.klunaMuted, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(Color.klunaAccent)
                            .frame(width: 12, height: 12)
                            .opacity(isSelected ? 1 : 0)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(plan == .yearly
                             ? (language == "de" ? "Jährlich" : "Yearly")
                             : (language == "de" ? "Monatlich" : "Monthly"))
                        .font(KlunaFont.heading(15))
                        .foregroundColor(.klunaPrimary)
                        if let badge {
                            Text(badge)
                                .font(KlunaFont.caption(10))
                                .foregroundColor(.klunaGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.klunaGreen.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                    Text(perMonth)
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                }
                Spacer()
                Text(price)
                    .font(KlunaFont.scoreDisplay(16))
                    .foregroundColor(.klunaPrimary)
            }
            .padding(KlunaSpacing.md)
            .background(Color.klunaSurface)
            .cornerRadius(KlunaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: KlunaRadius.card)
                    .stroke(isSelected ? Color.klunaAccent : Color.klunaBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

enum PaywallTrigger {
    case sessionLimit
    case dimensionLocked
    case playbackLocked
    case coachModeLocked
    case challengeLevelLocked
    case highScoreMoment
    case general

    func headline(language: String) -> String {
        switch self {
        case .sessionLimit:
            return language == "de" ? "Weiter trainieren?" : "Keep training?"
        case .dimensionLocked:
            return language == "de" ? "Sieh das volle Bild" : "See the full picture"
        case .playbackLocked:
            return language == "de" ? "Hör dir zu" : "Listen to yourself"
        case .coachModeLocked:
            return language == "de" ? "Dein persönlicher Coach" : "Your personal coach"
        case .challengeLevelLocked:
            return language == "de" ? "Bereit für mehr?" : "Ready for more?"
        case .highScoreMoment:
            return language == "de" ? "Du wirst besser!" : "You're getting better!"
        case .general:
            return language == "de" ? "Werde der beste Sprecher deiner selbst" : "Become the best speaker of yourself"
        }
    }

    func subheadline(language: String) -> String {
        switch self {
        case .sessionLimit:
            return language == "de"
            ? "3 Sessions diese Woche sind geschafft. Mit Pro trainierst du unbegrenzt."
            : "3 sessions this week are done. With Pro, train unlimited."
        case .dimensionLocked:
            return language == "de"
            ? "Dein Overall Score ist nur die Oberfläche. Sieh alle 6 Dimensionen."
            : "Your overall score is only the surface. See all 6 dimensions."
        case .playbackLocked:
            return language == "de"
            ? "Spiel deine Aufnahme ab und erkenne genaue Stärken und Einbrüche."
            : "Play your recording and identify exact strengths and drops."
        case .coachModeLocked:
            return language == "de"
            ? "Lass den KI-Coach deine Aufnahme zeitgenau kommentieren."
            : "Let the AI coach comment on your recording with timestamps."
        case .challengeLevelLocked:
            return language == "de"
            ? "Level 1-3 sind der Anfang. Schalte alle 15 Level frei."
            : "Levels 1-3 are just the start. Unlock all 15 levels."
        case .highScoreMoment:
            return language == "de"
            ? "Dein Fortschritt ist stark. Schalte alle Tools frei."
            : "Your progress is strong. Unlock all tools."
        case .general:
            return language == "de"
            ? "Alle Features. Unlimitiert. Wissenschaftlich fundiert."
            : "All features. Unlimited. Scientifically grounded."
        }
    }
}
