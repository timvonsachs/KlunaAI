import SwiftUI

struct KlunaColors {
    static let bg = Color(hex: "060A14")
    static let bgElevated = Color(hex: "0C1222")
    static let bgElevated2 = Color(hex: "121A30")
    static let bgElevated3 = Color(hex: "1A2340")

    static let accent = Color(hex: "22D97F")
    static let accentCyan = Color(hex: "06B6D4")
    static let accentGradient = LinearGradient(
        colors: [accent, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let energized = Color(hex: "22D97F")
    static let focused = Color(hex: "3B82F6")
    static let tense = Color(hex: "F97316")
    static let tired = Color(hex: "8B7EC8")
    static let relaxed = Color(hex: "06B6D4")

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case ..<40: return Color(hex: "EF4444")
        case ..<55: return Color(hex: "F97316")
        case ..<70: return Color(hex: "EAB308")
        case ..<82: return Color(hex: "22D97F")
        default: return Color(hex: "06D6A0")
        }
    }

    static func scoreGradient(_ score: Double) -> LinearGradient {
        let primary = scoreColor(score)
        let secondary: Color
        switch score {
        case ..<40: secondary = Color(hex: "DC2626")
        case ..<55: secondary = Color(hex: "EA580C")
        case ..<70: secondary = Color(hex: "CA8A04")
        case ..<82: secondary = Color(hex: "10B981")
        default: secondary = Color(hex: "00E5CC")
        }
        return LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let textPrimary = Color.white.opacity(0.93)
    static let textSecondary = Color.white.opacity(0.55)
    static let textMuted = Color.white.opacity(0.30)
    static let textGhost = Color.white.opacity(0.12)
}

struct KlunaFonts {
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func headline(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }
    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }
    static func upperLabel(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }
}

struct KlunaEffects {
    static func cardGlow(_ color: Color = KlunaColors.accent) -> some View {
        color.opacity(0.04).blur(radius: 40)
    }
    static func scoreGlow(_ score: Double) -> some View {
        KlunaColors.scoreColor(score).opacity(0.15).blur(radius: 60)
    }
    static func accentGlow() -> some View {
        KlunaColors.accent.opacity(0.08).blur(radius: 30)
    }
}
