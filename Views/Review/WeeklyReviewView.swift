import SwiftUI

struct WeeklyStats {
    let sessionCount: Int
    let avgScore: Double
    let highScore: Double
    let streak: Int
    let bestSession: (date: String, score: Double, highlight: String)?
    let scores: [Double]
    let previousWeekAvg: Double?
    let focusDimension: String?
    let improvement: Double
}

struct WeeklyReviewView: View {
    let weekStats: WeeklyStats
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WeekNumbersCard(stats: weekStats).tag(0)
            WeekBestMomentCard(stats: weekStats).tag(1)
            WeekGraphCard(stats: weekStats).tag(2)
            WeekFocusCard(stats: weekStats).tag(3)
            WeekShareCard(stats: weekStats).tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .background(NoiseBackground())
    }
}

private struct WeekCardShell<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
                .tracking(1.2)
                .textCase(.uppercase)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.klunaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
    }
}

private struct WeekNumbersCard: View {
    let stats: WeeklyStats
    var body: some View {
        WeekCardShell(title: "Woche in Zahlen") {
            HStack {
                stat("Sessions", "\(stats.sessionCount)")
                stat("Ø Score", "\(Int(stats.avgScore))")
                stat("Peak", "\(Int(stats.highScore))")
            }
            Text(stats.improvement >= 0 ? "+\(Int(stats.improvement)) zur Vorwoche" : "\(Int(stats.improvement)) zur Vorwoche")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(stats.improvement >= 0 ? .stateEnergized : .stateTense)
                .padding(.top, 2)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.klunaPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WeekBestMomentCard: View {
    let stats: WeeklyStats
    var body: some View {
        WeekCardShell(title: "Bester Moment") {
            if let best = stats.bestSession {
                Text(best.highlight)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.klunaPrimary)
                    .lineSpacing(3)
                HStack(spacing: 10) {
                    chip("Score \(Int(best.score))")
                    chip(best.date)
                }
            } else {
                Text("Diese Woche noch kein Highlight gespeichert.")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaSecondary)
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.klunaSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}

private struct WeekGraphCard: View {
    let stats: WeeklyStats
    var body: some View {
        WeekCardShell(title: "Trend") {
            GeometryReader { geo in
                let values = stats.scores
                let minScore = max(0.0, (values.min() ?? 0) - 8)
                let maxScore = min(100.0, (values.max() ?? 100) + 8)
                let range = max(1.0, maxScore - minScore)
                Path { path in
                    for (i, value) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(1, values.count - 1))
                        let y = geo.size.height - (geo.size.height * CGFloat(value - minScore) / CGFloat(range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(colors: [Color.stateEnergized, Color.stateRelaxed], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(height: 130)
        }
    }
}

private struct WeekFocusCard: View {
    let stats: WeeklyStats
    var body: some View {
        WeekCardShell(title: "Nächste Woche") {
            Text("Fokus: \(stats.focusDimension ?? "Gelassenheit")")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.klunaPrimary)
            Text("Plane 4 Sessions mit ruhigem Einstieg und stabiler Atmung. Ziel ist Konstanz statt Spitzen.")
                .font(.system(size: 14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(3)
        }
    }
}

private struct WeekShareCard: View {
    let stats: WeeklyStats
    var body: some View {
        WeekCardShell(title: "Teilen") {
            Text("Diese Woche: Ø \(Int(stats.avgScore)) · Peak \(Int(stats.highScore)) · \(stats.sessionCount) Sessions")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.klunaPrimary)
            Text("Copy-Text für Social wird hier angezeigt.")
                .font(.system(size: 13))
                .foregroundColor(.klunaSecondary)
            Button {
                // Hook für ShareSheet-Integration
            } label: {
                Text("Wochen-Review teilen")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.klunaPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.stateFocused.opacity(0.2)))
            }
        }
    }
}
