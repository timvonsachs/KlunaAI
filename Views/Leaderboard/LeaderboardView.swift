import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var leaderboardManager = LeaderboardManager()
    @State private var tab: LeaderboardTab = .topScore
    @State private var showPaywall = false

    private var entries: [LeaderboardEntry] {
        tab == .topScore ? leaderboardManager.globalTopScore : leaderboardManager.globalTopImprovement
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.klunaBackground.ignoresSafeArea()
                VStack(spacing: 12) {
                    Picker("", selection: $tab) {
                        Text(NSLocalizedString("top_score", comment: "")).tag(LeaderboardTab.topScore)
                        Text(NSLocalizedString("top_improvement", comment: "")).tag(LeaderboardTab.topImprovement)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: tab) { _ in Task { await leaderboardManager.fetchGlobalLeaderboard(tab: tab) } }

                    List(entries.prefix(20), id: \.id) { entry in
                        HStack {
                            Text(entry.rank <= 3 ? ["🥇", "🥈", "🥉"][entry.rank - 1] : "\(entry.rank).")
                                .frame(width: 28)
                            Text(entry.isCurrentUser ? "★ \(entry.username) ★" : entry.username)
                                .foregroundColor(entry.isCurrentUser ? .klunaAccent : .klunaPrimary)
                            Spacer()
                            Text("\(Int(entry.score))")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(entry.isCurrentUser ? Color.klunaAccent.opacity(0.15) : Color.klunaSurface)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)

                    if let me = entries.first(where: { $0.isCurrentUser }) {
                        Text("\(NSLocalizedString("your_rank", comment: "")) #\(me.rank) \(NSLocalizedString("of_50", comment: ""))")
                            .foregroundColor(.klunaMuted)
                            .padding(.bottom, 8)
                    }
                }
                if !subscriptionManager.hasLeaderboard {
                    lockOverlay
                }
            }
            .navigationTitle(L10n.leaderboard)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task { await leaderboardManager.fetchGlobalLeaderboard(tab: tab) }
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: 10) {
            Text("🔒")
                .font(.system(size: 40))
            Text(NSLocalizedString("leaderboard_locked", comment: ""))
                .foregroundColor(.klunaPrimary)
                .font(.headline)
            Button(L10n.upgradeToPro) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.klunaAccent)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding(24)
    }
}
