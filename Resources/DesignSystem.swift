import SwiftUI

extension Color {
    // MARK: Backgrounds
    static let klunaBackground = Color(hex: "0A0E1A")
    static let klunaSurface = Color(hex: "12172B")
    static let klunaSurfaceLight = Color(hex: "1A2040")
    static let klunaBorder = Color.white.opacity(0.06)

    // MARK: Text
    static let klunaPrimary = Color.white.opacity(0.95)
    static let klunaSecondary = Color.white.opacity(0.55)
    static let klunaMuted = Color.white.opacity(0.30)

    // MARK: Accent
    static let klunaAccent = Color(hex: "22D97F")
    static let klunaAccentLight = Color(hex: "06D6A0")
    static let klunaAccentDark = Color(hex: "10B981")
    static let klunaAccentGlow = Color(hex: "22D97F").opacity(0.3)

    // MARK: Vocal States
    static let stateEnergized = Color(hex: "22D97F")
    static let stateFocused = Color(hex: "3B82F6")
    static let stateTense = Color(hex: "F97316")
    static let stateTired = Color(hex: "8B7EC8")
    static let stateRelaxed = Color(hex: "06B6D4")

    // MARK: Score Colors
    static let klunaGreen = Color(hex: "22D97F")
    static let klunaAmber = Color(hex: "EAB308")
    static let klunaOrange = Color(hex: "F97316")
    static let klunaRed = Color(hex: "EF4444")

    // MARK: Special
    static let klunaGold = Color(hex: "FFD700")
    static let klunaGreenGlow = Color(hex: "00D2A0").opacity(0.3)

    static func forScore(_ score: Double) -> Color {
        switch score {
        case 80...100: return .klunaGreen
        case 65..<80: return .klunaAccent
        case 50..<65: return .klunaAmber
        case 35..<50: return .klunaOrange
        default: return .klunaRed
        }
    }

    static func gradientForScore(_ score: Double) -> LinearGradient {
        let colors: [Color]
        switch score {
        case 0..<40:
            colors = [Color(hex: "F97316"), Color(hex: "EF4444")]
        case 40..<60:
            colors = [Color(hex: "F97316"), Color(hex: "EAB308")]
        case 60..<80:
            colors = [Color(hex: "22D97F"), Color(hex: "10B981")]
        default:
            colors = [Color(hex: "06D6A0"), Color(hex: "00E5CC")]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

enum KlunaFont {
    static func scoreDisplay(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func scoreLarge(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func scoreLight(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded)
    }
    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
    static func caption(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }
}

enum KlunaAnimation {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let springFast = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    static let easeOut = Animation.spring(response: 0.45, dampingFraction: 0.78)
    static let scoreReveal = Animation.spring(response: 0.6, dampingFraction: 0.72)
    static let stagger: TimeInterval = 0.12
    static let breathe = Animation.spring(response: 1.4, dampingFraction: 0.82).repeatForever(autoreverses: true)
}

enum KlunaSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum KlunaRadius {
    static let button: CGFloat = 12
    static let card: CGFloat = 16
    static let pill: CGFloat = 20
    static let ring: CGFloat = 24
}

enum L10n {
    static var dashboard: String { localized("dashboard") }
    static var record: String { localized("record") }
    static var practice: String { localized("practice") }
    static var history: String { localized("history") }
    static var leaderboard: String { localized("leaderboard") }
    static var team: String { localized("team") }
    static var settings: String { localized("settings") }

    static var tapToRecord: String { localized("tap_to_record") }
    static var listening: String { localized("listening") }
    static var analyzing: String { localized("analyzing") }
    static var stopRecording: String { localized("stop_recording") }
    static var startRecording: String { localized("start_recording") }
    static var doubleTapToToggle: String { localized("double_tap_toggle") }
    static var preliminary: String { localized("preliminary") }

    static var overallScore: String { localized("overall_score") }
    static var yourWeeklyScore: String { localized("your_weekly_score") }
    static var sessions: String { localized("sessions") }
    static var best: String { localized("best") }
    static var streak: String { localized("streak") }
    static var thisWeek: String { localized("this_week") }
    static var lastSession: String { localized("last_session") }
    static var allSessions: String { localized("all_sessions") }
    static var dimensions: String { localized("dimensions") }

    static var coachSays: String { localized("coach_says") }
    static var yourCoachSays: String { localized("your_coach_says") }
    static var weeklyReportLocked: String { localized("weekly_report_locked") }
    static var sessionsThisWeek: String { localized("sessions_this_week") }
    static var hint: String { localized("hint") }
    static var openSettings: String { localized("open_settings") }
    static var proFeature: String { localized("pro_feature") }
    static var deepCoaching: String { localized("deep_coaching") }
    static var again: String { localized("again") }
    static var beatYourScore: String { localized("beat_your_score") }
    static var done: String { localized("done") }
    static var upgradeToPro: String { localized("upgrade_to_pro") }
    static var upgrade: String { localized("upgrade") }
    static var whatYouSaid: String { localized("what_you_said") }
    static var performanceOverTime: String { localized("performance_over_time") }
    static var start: String { localized("start") }
    static var middle: String { localized("middle") }
    static var end: String { localized("end") }
    static var excellent: String { localized("excellent") }
    static var strong: String { localized("strong") }
    static var solid: String { localized("solid") }
    static var developing: String { localized("developing") }
    static var starting: String { localized("starting") }

    static var profile: String { localized("profile") }
    static var training: String { localized("training") }
    static var subscription: String { localized("subscription") }
    static var app: String { localized("app") }
    static var version: String { localized("version") }
    static var name: String { localized("name") }
    static var language: String { localized("language") }
    static var voiceType: String { localized("voice_type") }
    static var goal: String { localized("goal") }
    static var weeklyGoal: String { localized("weekly_goal") }

    static var confidence: String { localized("confidence") }
    static var energy: String { localized("energy") }
    static var tempo: String { localized("tempo") }
    static var clarity: String { localized("clarity") }
    static var stability: String { localized("stability") }
    static var charisma: String { localized("dimension_charisma") }

    static var voiceTypeTitle: String { localized("voice_type_title") }
    static var voiceTypeDeep: String { localized("voice_type_deep") }
    static var voiceTypeMid: String { localized("voice_type_mid") }
    static var voiceTypeHigh: String { localized("voice_type_high") }
    static var voiceTypeHint: String { localized("voice_type_hint") }

    static var goalTitle: String { localized("goal_title") }
    static var goalPitches: String { localized("goal_pitches") }
    static var goalContent: String { localized("goal_content") }
    static var goalInterviews: String { localized("goal_interviews") }
    static var goalConfidence: String { localized("goal_confidence") }

    static var focusDimensions: String { localized("focus_dimensions") }
    static var weeklyReport: String { localized("weekly_report") }
    static var yourRecording: String { localized("your_recording") }
    static var listenToYourself: String { localized("listen_to_yourself") }
    static var dailyChallenge: String { localized("daily_challenge") }
    static var acceptChallenge: String { localized("accept_challenge") }
    static var completed: String { localized("completed") }
    static var yourChallenge: String { localized("your_challenge") }
    static var vocalWarmup: String { localized("vocal_warmup") }
    static var warmupSubtitle: String { localized("warmup_subtitle") }
    static var startWarmup: String { localized("start_warmup") }
    static var next: String { localized("next") }
    static var skip: String { localized("skip") }
    static var warmUpFirst: String { localized("warm_up_first") }
    static var greatImprovement: String { localized("great_improvement") }
    static var gettingBetter: String { localized("getting_better") }
    static var tryAgainTip: String { localized("try_again_tip") }
    static var attempt: String { localized("attempt") }
    static var keepGoing: String { localized("keep_going") }
    static var yourPersonalBest: String { localized("your_personal_best") }
    static var yourProgress: String { localized("your_progress") }
    static var firstSessions: String { localized("first_sessions") }
    static var yourFirstSessions: String { localized("your_first_sessions") }
    static var yourCurrentScore: String { localized("your_current_score") }
    static var now: String { localized("now") }
    static var targetedDrill: String { localized("targeted_drill") }
    static var before: String { localized("before") }
    static var after: String { localized("after") }
    static var drill: String { localized("drill") }
    static var voiceJournal: String { localized("voice_journal") }
    static var recording: String { localized("recording") }
    static var tapToStart: String { localized("tap_to_start") }
    static var coachMode: String { localized("coach_mode") }
    static var calibration: String { localized("calibration") }
    static var personallyCalibrated: String { localized("personally_calibrated") }
    static var startKlunaPro: String { localized("start_kluna_pro") }
    static var restorePurchases: String { localized("restore_purchases") }
    static var sessionsThisWeekRemaining: String { localized("sessions_this_week_remaining") }
    static var howKlunaMeasures: String { localized("how_kluna_measures") }
    static var howItWorks: String { localized("how_it_works") }
    static var measuredBiomarkers: String { localized("measured_biomarkers") }
    static var tipToImprove: String { localized("tip_to_improve") }
    static var scientificBasis: String { localized("scientific_basis") }
    static var yourGoal: String { localized("your_goal") }
    static var goalReached: String { localized("goal_reached") }
    static var nextGoal: String { localized("next_goal") }
    static var biomarkerChallenge: String { localized("biomarker_challenge") }
    static var klunaMeasuresRealtime: String { localized("kluna_measures_realtime") }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
