import SwiftUI

struct ProfileView: View {
    let level: LevelInfo
    let consistency: ConsistencyResult
    let logs: [SessionFeatureLog]
    let milestones: [String]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    PremiumLevelRing(level: level)
                    Text(level.tierName)
                        .font(KlunaFonts.upperLabel(10))
                        .foregroundColor(KlunaColors.textMuted)
                        .tracking(1.5)
                        .textCase(.uppercase)
                    Text(level.title)
                        .font(KlunaFonts.headline(20))
                        .foregroundColor(KlunaColors.textPrimary)
                    Text("\(level.totalXP) XP gesamt")
                        .font(KlunaFonts.label(13))
                        .foregroundColor(KlunaColors.textMuted)
                }
                .padding(.top, 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ProfileStat(value: "\(logs.count)", label: "Sessions")
                    ProfileStat(value: "\(consistency.longestStreak)", label: "Längster Streak")
                    ProfileStat(value: "\(Int(logs.compactMap { $0.scoreOverall }.max() ?? 0))", label: "Höchster Score")
                }

                if DiscoveryStateManager.shared.isDiscoveryComplete, let dna = latestVoiceDNA {
                    VoiceDNARadarView(profile: dna)
                }

                if !milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MEILENSTEINE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.klunaMuted)
                            .tracking(1.2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(milestones, id: \.self) { id in
                                    PremiumMilestoneBadge(id: id, achieved: true)
                                }
                            }
                        }
                    }
                }

                if let firstLog = logs.first,
                   let date = ISO8601DateFormatter().date(from: firstLog.timestamp) {
                    VStack(spacing: 4) {
                        Text("Mitglied seit \(formattedDate(date))")
                            .font(.system(size: 13))
                            .foregroundColor(.klunaSecondary)
                        Text("\(logs.count) Sessions · \(Int(totalMinutes)) Minuten Stimmtraining")
                            .font(.system(size: 12))
                            .foregroundColor(.klunaMuted)
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(NoiseBackground())
    }

    private var totalMinutes: Double {
        logs.map(\.durationSeconds).reduce(0, +) / 60
    }

    private var latestVoiceDNA: VoiceDNAProfile? {
        for entry in logs.reversed() {
            guard
                let authority = entry.dnaAuthority,
                let charisma = entry.dnaCharisma,
                let warmth = entry.dnaWarmth,
                let composure = entry.dnaComposure
            else { continue }
            return VoiceDNAProfile(
                authority: Float(authority),
                charisma: Float(charisma),
                warmth: Float(warmth),
                composure: Float(composure)
            )
        }
        return nil
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: date)
    }

    private func formatMilestone(_ id: String) -> String {
        id
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct PremiumLevelRing: View {
    let level: LevelInfo
    @State private var rotateGradient = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 5)
                .frame(width: 90, height: 90)
            Circle()
                .trim(from: 0, to: level.progress)
                .stroke(
                    AngularGradient(
                        colors: [KlunaColors.accent, KlunaColors.accentCyan, KlunaColors.accent],
                        center: .center,
                        startAngle: .degrees(rotateGradient ? 0 : 360),
                        endAngle: .degrees(rotateGradient ? 360 : 720)
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(.degrees(-90))
                .shadow(color: KlunaColors.accent.opacity(0.3), radius: 8)
            Text("\(level.level)")
                .font(KlunaFonts.score(32))
                .foregroundColor(KlunaColors.textPrimary)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotateGradient = true
            }
        }
    }
}

struct PremiumMilestoneBadge: View {
    let id: String
    let achieved: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(achieved ? badgeColor.opacity(0.12) : Color.white.opacity(0.03))
                    .frame(width: 48, height: 48)
                if achieved {
                    Circle()
                        .stroke(badgeColor.opacity(0.3), lineWidth: 1)
                        .frame(width: 48, height: 48)
                }
                Text(badgeIcon)
                    .font(.system(size: 20))
                    .opacity(achieved ? 1.0 : 0.25)
            }
            Text(badgeLabel)
                .font(KlunaFonts.label(8))
                .foregroundColor(achieved ? KlunaColors.textSecondary : KlunaColors.textGhost)
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    private var badgeIcon: String {
        switch id {
        case "sessions_5": return "5️⃣"
        case "sessions_10": return "🔟"
        case "sessions_25": return "🎯"
        case "sessions_50": return "🏆"
        case "sessions_100": return "💎"
        case "streak_7": return "🔥"
        case "streak_30": return "🌟"
        case "score_70": return "📈"
        case "score_80": return "🚀"
        case "score_90": return "👑"
        case let s where s.hasPrefix("consistency"): return "💪"
        default: return "✨"
        }
    }

    private var badgeLabel: String {
        switch id {
        case "sessions_5": return "5 Sessions"
        case "sessions_10": return "10 Sessions"
        case "sessions_25": return "25 Sessions"
        case "sessions_50": return "50 Sessions"
        case "sessions_100": return "100 Sessions"
        case "streak_7": return "7-Tage Streak"
        case "streak_30": return "30-Tage Streak"
        case "score_70": return "Score 70+"
        case "score_80": return "Score 80+"
        case "score_90": return "Score 90+"
        case "consistency_60": return "Konsistenz 60"
        case "consistency_80": return "Konsistenz 80"
        default:
            return id.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var badgeColor: Color {
        switch id {
        case let s where s.contains("streak"): return KlunaColors.tense
        case let s where s.contains("score"): return KlunaColors.accent
        case let s where s.contains("consistency"): return KlunaColors.focused
        case let s where s.contains("sessions"): return KlunaColors.accentCyan
        default: return KlunaColors.textSecondary
        }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.klunaPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.klunaMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
    }
}
