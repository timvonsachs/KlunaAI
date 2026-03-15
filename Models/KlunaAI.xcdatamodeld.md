// KlunaAI.xcdatamodeld – CoreData Model Definition
//
// Create the actual .xcdatamodeld in Xcode.
//
// === Entities ===
//
// Session
//   - id: UUID
//   - date: Date
//   - pitchType: String
//   - duration: Double
//   - overallScore: Double
//   - confidenceScore: Double
//   - energyScore: Double
//   - tempoScore: Double
//   - clarityScore: Double
//   - stabilityScore: Double
//   - persuasivenessScore: Double
//   - featureZScoresData: Binary (JSON [String: Double])
//   - transcription: String
//   - quickFeedback: String
//   - deepCoaching: String (optional)
//   - heatmapData: Binary (JSON)
//
// Baseline
//   - feature: String (e.g. "F0Mean", "Jitter")
//   - ewmaMean: Double
//   - ewmaVariance: Double
//   - sampleCount: Integer 32
//   - lastUpdated: Date
//
// UserProfile
//   - name: String
//   - language: String ("de" / "en")
//   - weeklyGoal: Integer 16
//   - currentStreak: Integer 32
//   - firstSessionDate: Date
//   - longTermProfile: String (optional)
//   - strengthsData: Binary (JSON [String])
//   - weaknessesData: Binary (JSON [String])
//   - teamCode: String (optional)
//   - role: String ("consumer" / "member" / "admin")
//
// PitchType
//   - id: UUID
//   - name: String
//   - pitchDescription: String
//   - timeLimit: Integer 32 (optional, 0 = no limit)
//   - isCustom: Boolean
//   - isDefault: Boolean
//
// Challenge
//   - id: UUID
//   - title: String
//   - challengeDescription: String
//   - type: String (ChallengeType raw value)
//   - target: Double
//   - progress: Double
//   - expiresAt: Date
//
// === Notes ===
// - NSFileProtectionComplete enabled
// - No CloudKit sync (privacy first)
// - B2B team data syncs via backend, not CoreData
