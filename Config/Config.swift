import Foundation

/// Central configuration for Kluna AI.
enum Config {
    
    // MARK: - API

    // Security baseline: do not commit live secrets.
    // Provide keys via environment variables, Info.plist build settings, or UserDefaults.
    private static let bundledClaudeAPIKey = ""
    private static let bundledOpenAIAPIKey = ""
    private static let bundledSupabaseProjectURL = ""
    private static let bundledSupabaseAnonKey = ""
    
    static var claudeAPIKey: String {
        #if DEBUG
        if DebugConfig.disableClaudeAPI {
            return ""
        }
        #endif
        if !bundledClaudeAPIKey.isEmpty { return bundledClaudeAPIKey }
        if let env = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"], !env.isEmpty { return env }
        if let info = Bundle.main.object(forInfoDictionaryKey: "CLAUDE_API_KEY") as? String, !info.isEmpty { return info }
        if let defaultsValue = UserDefaults.standard.string(forKey: "CLAUDE_API_KEY"), !defaultsValue.isEmpty { return defaultsValue }
        return ""
    }

    static var openAIAPIKey: String {
        if !bundledOpenAIAPIKey.isEmpty { return bundledOpenAIAPIKey }
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty { return env }
        if let info = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !info.isEmpty { return info }
        if let defaultsValue = UserDefaults.standard.string(forKey: "openai_api_key"), !defaultsValue.isEmpty { return defaultsValue }
        return ""
    }

    static var supabaseProjectURL: String {
        if let env = ProcessInfo.processInfo.environment["SUPABASE_PROJECT_URL"], !env.isEmpty {
            return env
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PROJECT_URL") as? String, !info.isEmpty {
            return info
        }
        if let defaultsValue = UserDefaults.standard.string(forKey: "SUPABASE_PROJECT_URL"), !defaultsValue.isEmpty {
            return defaultsValue
        }
        if !bundledSupabaseProjectURL.isEmpty {
            return bundledSupabaseProjectURL
        }
        return ""
    }

    static var supabaseAnonKey: String {
        if let env = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !env.isEmpty {
            return env
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !info.isEmpty {
            return info
        }
        if let defaultsValue = UserDefaults.standard.string(forKey: "SUPABASE_ANON_KEY"), !defaultsValue.isEmpty {
            return defaultsValue
        }
        if !bundledSupabaseAnonKey.isEmpty {
            return bundledSupabaseAnonKey
        }
        return ""
    }
    
    static let claudeModel = "claude-sonnet-4-20250514"
    static let claudeCandidateModels = [
        "claude-3-5-sonnet-latest",
        "claude-3-7-sonnet-latest",
        "claude-3-5-haiku-latest",
        "claude-3-haiku-20240307",
        "claude-3-5-sonnet-20241022",
        "claude-3-7-sonnet-20250219",
        "claude-sonnet-4-20250514",
    ]
    static let quickFeedbackMaxTokens = 200
    static let deepCoachingMaxTokens = 600
    static let strengthsUpdateMaxTokens = 150
    
    // MARK: - Baseline
    
    static let ewmaAlpha = 0.1
    static let baselineMinSessions = 21
    static let profileTriggerSessions = 30
    
    // MARK: - Dimension Weights
    
    static let dimensionWeights: [PerformanceDimension: Double] = [
        .confidence: 0.22,
        .energy: 0.18,
        .tempo: 0.15,
        .stability: 0.18,
        .charisma: 0.27,
    ]
    
    // MARK: - Score Normalization
    
    /// Converts Z-Score to 0-100: score = 50 + (zScore × scaleFactor)
    static let scoreScaleFactor = 15.0
    static let scoreMin = 0.0
    static let scoreMax = 100.0
    
    // MARK: - Audio
    
    static let audioSampleRate: Double = 16000
    static let audioChunkDuration: TimeInterval = 2.0
    
    // MARK: - Gamification
    
    static let streakGoalOptions = [3, 5, 7]  // Sessions per week
    static let streakMilestones = [4, 12, 26, 52]  // Weeks
    
    // MARK: - Monetization
    
    static let freeSessionsPerWeek = 3
    static let proMonthlyPrice = 20.0   // EUR
    static let proYearlyPrice = 180.0   // EUR (15/month)
    static let teamMinUsers = 5
    static let teamPricePerUser = 125.0 // EUR/month
    
    static let proMonthlyProductID = "com.kluna.pro.monthly"
    static let proYearlyProductID = "com.kluna.pro.yearly"
    
    // MARK: - Heatmap
    
    static let heatmapSegments = 3  // First, middle, last third
    
    // MARK: - Memory
    
    static let recentSessionsCount = 5
    static let maxStrengths = 3
    static let maxWeaknesses = 3
}
