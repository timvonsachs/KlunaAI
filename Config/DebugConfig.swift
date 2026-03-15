#if DEBUG
enum DebugConfig {
    static let skipOnboarding = false
    static let forceProSubscription = true
    static let showTimingLogs = true
    static let useMockScores = false
    static let disableClaudeAPI = false

    static let mockScores = DimensionScores(
        confidence: 74,
        energy: 68,
        tempo: 55,
        clarity: 72,
        stability: 61,
        charisma: 66
    )
}
#endif
