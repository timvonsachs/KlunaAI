import CoreData
import Foundation

private enum MapperCoder {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}

extension CDSession {
    func toCompletedSession() -> CompletedSession {
        let features: [String: Double] = {
            guard let data = featureZScoresData else { return [:] }
            return (try? MapperCoder.decoder.decode([String: Double].self, from: data)) ?? [:]
        }()
        let heatmap: HeatmapData = {
            guard let data = heatmapData else { return HeatmapData(segments: []) }
            return (try? MapperCoder.decoder.decode(HeatmapData.self, from: data)) ?? HeatmapData(segments: [])
        }()
        let dnaProfile: VoiceDNAProfile? = {
            let values = [dnaAuthority, dnaCharisma, dnaWarmth, dnaComposure]
            guard values.contains(where: { $0 > 0 }) else { return nil }
            return VoiceDNAProfile(
                authority: dnaAuthority,
                charisma: dnaCharisma,
                warmth: dnaWarmth,
                composure: dnaComposure
            )
        }()
        return CompletedSession(
            id: id ?? UUID(),
            date: date ?? Date(),
            pitchType: pitchType ?? "",
            duration: duration,
            scores: DimensionScores(
                confidence: confidenceScore,
                energy: energyScore,
                tempo: tempoScore,
                clarity: clarityScore,
                stability: stabilityScore,
                charisma: charismaScore
            ),
            featureZScores: features,
            transcription: transcription ?? "",
            quickFeedback: quickFeedback ?? "",
            deepCoaching: deepCoaching,
            heatmapData: heatmap,
            profileName: profileName,
            profileRank: profileRank > 0 ? Int(profileRank) : nil,
            profileConfidence: profileConfidence > 0 ? profileConfidence : nil,
            voiceDNA: dnaProfile
        )
    }

    static func from(_ session: CompletedSession, context: NSManagedObjectContext) -> CDSession {
        let entity = CDSession(context: context)
        entity.id = session.id
        entity.date = session.date
        entity.pitchType = session.pitchType
        entity.duration = session.duration
        entity.overallScore = session.scores.overall
        entity.confidenceScore = session.scores.confidence
        entity.energyScore = session.scores.energy
        entity.tempoScore = session.scores.tempo
        entity.clarityScore = session.scores.clarity
        entity.stabilityScore = session.scores.stability
        entity.charismaScore = session.scores.charisma
        entity.featureZScoresData = try? MapperCoder.encoder.encode(session.featureZScores)
        entity.transcription = session.transcription
        entity.quickFeedback = session.quickFeedback
        entity.deepCoaching = session.deepCoaching
        entity.heatmapData = try? MapperCoder.encoder.encode(session.heatmapData)
        entity.profileName = session.profileName
        entity.profileRank = Int16(session.profileRank ?? 0)
        entity.profileConfidence = session.profileConfidence ?? 0
        entity.dnaAuthority = session.voiceDNA?.authority ?? 0
        entity.dnaCharisma = session.voiceDNA?.charisma ?? 0
        entity.dnaWarmth = session.voiceDNA?.warmth ?? 0
        entity.dnaComposure = session.voiceDNA?.composure ?? 0
        return entity
    }

    func toSessionSummary() -> SessionSummary {
        let scores = DimensionScores(
            confidence: confidenceScore,
            energy: energyScore,
            tempo: tempoScore,
            clarity: clarityScore,
            stability: stabilityScore,
            charisma: charismaScore
        )
        let weakest = [
            (PerformanceDimension.confidence, confidenceScore),
            (PerformanceDimension.energy, energyScore),
            (PerformanceDimension.tempo, tempoScore),
            (PerformanceDimension.stability, stabilityScore),
            (PerformanceDimension.charisma, charismaScore),
        ].min(by: { $0.1 < $1.1 })?.0 ?? .confidence

        return SessionSummary(
            date: MapperCoder.dateFormatter.string(from: date ?? Date()),
            pitchType: pitchType ?? "",
            overallScore: overallScore,
            weakestDimension: weakest,
            scores: scores
        )
    }
}

extension CDUserProfile {
    func toKlunaUser(totalSessions: Int) -> KlunaUser {
        let strengths = (strengthsData.flatMap { try? MapperCoder.decoder.decode([String].self, from: $0) }) ?? []
        let weaknesses = (weaknessesData.flatMap { try? MapperCoder.decoder.decode([String].self, from: $0) }) ?? []
        return KlunaUser(
            name: name ?? "",
            language: language ?? "en",
            firstSessionDate: firstSessionDate ?? Date(),
            totalSessions: totalSessions,
            weeklyGoal: Int(weeklyGoal),
            currentStreak: Int(currentStreak),
            strengths: strengths,
            weaknesses: weaknesses,
            longTermProfile: longTermProfile,
            teamCode: teamCode,
            role: UserRole(rawValue: role ?? "consumer") ?? .consumer,
            voiceType: VoiceType(rawValue: voiceType ?? VoiceType.mid.rawValue) ?? .mid,
            goal: UserGoal(rawValue: goal ?? UserGoal.pitches.rawValue) ?? .pitches
        )
    }

    static func from(_ user: KlunaUser, context: NSManagedObjectContext) -> CDUserProfile {
        let entity = CDUserProfile(context: context)
        entity.apply(user: user)
        return entity
    }

    func apply(user: KlunaUser) {
        name = user.name
        language = user.language
        weeklyGoal = Int16(user.weeklyGoal)
        currentStreak = Int32(user.currentStreak)
        firstSessionDate = user.firstSessionDate
        longTermProfile = user.longTermProfile
        strengthsData = try? MapperCoder.encoder.encode(user.strengths)
        weaknessesData = try? MapperCoder.encoder.encode(user.weaknesses)
        teamCode = user.teamCode
        role = user.role.rawValue
        voiceType = user.voiceType.rawValue
        goal = user.goal.rawValue
    }
}

extension CDPitchType {
    func toPitchType() -> PitchType {
        PitchType(
            id: id ?? UUID(),
            name: name ?? "",
            description: pitchDescription ?? "",
            timeLimit: timeLimit > 0 ? Int(timeLimit) : nil,
            isCustom: isCustom,
            isDefault: isDefault
        )
    }

    static func from(_ pitchType: PitchType, context: NSManagedObjectContext) -> CDPitchType {
        let entity = CDPitchType(context: context)
        entity.id = pitchType.id
        entity.name = pitchType.name
        entity.pitchDescription = pitchType.description
        entity.timeLimit = Int32(pitchType.timeLimit ?? 0)
        entity.isCustom = pitchType.isCustom
        entity.isDefault = pitchType.isDefault
        return entity
    }
}

extension CDChallenge {
    func toChallenge() -> Challenge {
        Challenge(
            id: id ?? UUID(),
            title: title ?? "",
            description: challengeDescription ?? "",
            type: ChallengeType(rawValue: type ?? "") ?? .sessionCount,
            target: target,
            progress: progress,
            expiresAt: expiresAt ?? Date()
        )
    }

    static func from(_ challenge: Challenge, context: NSManagedObjectContext) -> CDChallenge {
        let entity = CDChallenge(context: context)
        entity.id = challenge.id
        entity.title = challenge.title
        entity.challengeDescription = challenge.description
        entity.type = challenge.type.rawValue
        entity.target = challenge.target
        entity.progress = challenge.progress
        entity.expiresAt = challenge.expiresAt
        return entity
    }
}
