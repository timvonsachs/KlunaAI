import SwiftUI

// MARK: - View Stubs

struct HeatmapView: View {
    let data: HeatmapData
    var body: some View {
        // TODO: Grid showing dimensions × time segments
        // Green/Yellow/Red cells
        Text("Heatmap").foregroundColor(.klunaMuted)
            .padding().frame(maxWidth: .infinity)
            .background(Color.klunaSurface).cornerRadius(16)
    }
}

struct TeamView: View {
    var body: some View {
        NavigationView {
            // TODO: Team leaderboard, challenges, admin dashboard (if admin)
            Text("Team").navigationTitle(L10n.team)
        }
    }
}

// MARK: - Analytics Sub-views (Stubs)

struct ScoreTrendGraphView: View {
    var body: some View {
        // TODO: Line chart – overall + dimensions over weeks
        RoundedRectangle(cornerRadius: 16).fill(Color.klunaSurface)
            .frame(height: 200).overlay(Text("Score Trend").foregroundColor(.klunaMuted))
    }
}

struct DimensionsRadarView: View {
    var body: some View {
        // TODO: Spider web chart – 6 axes, 7-day vs 30-day
        RoundedRectangle(cornerRadius: 16).fill(Color.klunaSurface)
            .frame(height: 200).overlay(Text("Radar").foregroundColor(.klunaMuted))
    }
}

struct ActiveChallengesView: View {
    var body: some View {
        // TODO: Active challenges with progress bars
        RoundedRectangle(cornerRadius: 16).fill(Color.klunaSurface)
            .frame(height: 120).overlay(Text("Challenges").foregroundColor(.klunaMuted))
    }
}

struct StreakBannerView: View {
    var body: some View {
        // TODO: Fire icon + week count + sessions this week
        HStack {
            Image(systemName: "flame.fill").foregroundColor(.klunaOrange)
            Text("0 weeks").foregroundColor(.klunaPrimary)
            Spacer()
        }
        .padding().background(Color.klunaSurface).cornerRadius(12)
    }
}

struct QuickStatsStubView: View {
    var body: some View {
        // TODO: Total sessions, avg score, all-time best
        HStack(spacing: 12) {
            LegacyStatCard(title: "Sessions", value: "0")
            LegacyStatCard(title: "Avg Score", value: "–")
            LegacyStatCard(title: "Best", value: "–")
        }
    }
}

struct LegacyStatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 24, weight: .bold)).foregroundColor(.klunaPrimary)
            Text(title).font(.system(size: 12)).foregroundColor(.klunaMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.klunaSurface)
        .cornerRadius(12)
    }
}

struct AnalyticsPaywallTeaser: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill").font(.system(size: 32)).foregroundColor(.klunaAccent)
            Text(L10n.upgradeToPro).foregroundColor(.klunaAccent).font(.system(size: 16, weight: .medium))
            Text("Unlock analytics, streaks, leaderboards and more")
                .font(.system(size: 14)).foregroundColor(.klunaMuted).multilineTextAlignment(.center)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(Color.klunaSurface).cornerRadius(16)
    }
}
