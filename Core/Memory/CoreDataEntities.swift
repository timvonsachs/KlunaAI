import CoreData
import Foundation

@objc(CDSession)
public class CDSession: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDSession> {
        NSFetchRequest<CDSession>(entityName: "CDSession")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var pitchType: String?
    @NSManaged public var duration: Double
    @NSManaged public var overallScore: Double
    @NSManaged public var confidenceScore: Double
    @NSManaged public var energyScore: Double
    @NSManaged public var tempoScore: Double
    @NSManaged public var clarityScore: Double
    @NSManaged public var stabilityScore: Double
    @NSManaged public var charismaScore: Double
    @NSManaged public var featureZScoresData: Data?
    @NSManaged public var transcription: String?
    @NSManaged public var quickFeedback: String?
    @NSManaged public var deepCoaching: String?
    @NSManaged public var heatmapData: Data?
    @NSManaged public var profileName: String?
    @NSManaged public var profileRank: Int16
    @NSManaged public var profileConfidence: Double
    @NSManaged public var dnaAuthority: Float
    @NSManaged public var dnaCharisma: Float
    @NSManaged public var dnaWarmth: Float
    @NSManaged public var dnaComposure: Float
}

@objc(CDBaseline)
public class CDBaseline: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDBaseline> {
        NSFetchRequest<CDBaseline>(entityName: "CDBaseline")
    }

    @NSManaged public var feature: String?
    @NSManaged public var ewmaMean: Double
    @NSManaged public var ewmaVariance: Double
    @NSManaged public var sampleCount: Int32
    @NSManaged public var lastUpdated: Date?
}

@objc(CDUserProfile)
public class CDUserProfile: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDUserProfile> {
        NSFetchRequest<CDUserProfile>(entityName: "CDUserProfile")
    }

    @NSManaged public var name: String?
    @NSManaged public var language: String?
    @NSManaged public var weeklyGoal: Int16
    @NSManaged public var currentStreak: Int32
    @NSManaged public var firstSessionDate: Date?
    @NSManaged public var longTermProfile: String?
    @NSManaged public var strengthsData: Data?
    @NSManaged public var weaknessesData: Data?
    @NSManaged public var teamCode: String?
    @NSManaged public var role: String?
    @NSManaged public var voiceType: String?
    @NSManaged public var goal: String?
}

@objc(CDPitchType)
public class CDPitchType: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDPitchType> {
        NSFetchRequest<CDPitchType>(entityName: "CDPitchType")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var pitchDescription: String?
    @NSManaged public var timeLimit: Int32
    @NSManaged public var isCustom: Bool
    @NSManaged public var isDefault: Bool
}

@objc(CDChallenge)
public class CDChallenge: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDChallenge> {
        NSFetchRequest<CDChallenge>(entityName: "CDChallenge")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var challengeDescription: String?
    @NSManaged public var type: String?
    @NSManaged public var target: Double
    @NSManaged public var progress: Double
    @NSManaged public var expiresAt: Date?
}

@objc(CDJournalEntry)
public class CDJournalEntry: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDJournalEntry> {
        NSFetchRequest<CDJournalEntry>(entityName: "CDJournalEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var rawFeaturesJSON: Data?
    @NSManaged public var mood: String?
    @NSManaged public var transcription: String?
    @NSManaged public var recordingURL: String?
    @NSManaged public var audioRelativePath: String?
    @NSManaged public var prompt: String?
    @NSManaged public var arousal: Float
    @NSManaged public var acousticValence: Float
    @NSManaged public var quadrant: String?
    @NSManaged public var moodLabel: String?
    @NSManaged public var coachText: String?
    @NSManaged public var themesRaw: String?
    @NSManaged public var pillarVQ: Float
    @NSManaged public var pillarClarity: Float
    @NSManaged public var pillarDynamics: Float
    @NSManaged public var pillarRhythm: Float
    @NSManaged public var overallScore: Float
    @NSManaged public var deltaArousal: Float
    @NSManaged public var deltaValence: Float
    @NSManaged public var f0Mean: Float
    @NSManaged public var f0Range: Float
    @NSManaged public var jitter: Float
    @NSManaged public var shimmer: Float
    @NSManaged public var hnr: Float
    @NSManaged public var speechRate: Float
    @NSManaged public var pauseRate: Float
    @NSManaged public var loudnessMean: Float
    @NSManaged public var loudnessRange: Float
    @NSManaged public var flagsRaw: String?
    @NSManaged public var warmth: Float
    @NSManaged public var stability: Float
    @NSManaged public var energy: Float
    @NSManaged public var tempo: Float
    @NSManaged public var openness: Float
    @NSManaged public var conversationId: UUID?
    @NSManaged public var roundIndex: Int16
    @NSManaged public var deltaEnergy: Float
    @NSManaged public var deltaTension: Float
    @NSManaged public var deltaFatigue: Float
    @NSManaged public var deltaWarmth: Float
    @NSManaged public var deltaExpressiveness: Float
    @NSManaged public var deltaTempo: Float
    @NSManaged public var cardTitle: String?
    @NSManaged public var cardRarity: String?
    @NSManaged public var cardAtmosphereHex: String?
    @NSManaged public var voiceObservation: String?
}

@objc(CDConversation)
public class CDConversation: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDConversation> {
        NSFetchRequest<CDConversation>(entityName: "CDConversation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var roundCount: Int16
    @NSManaged public var isComplete: Bool
    @NSManaged public var memorySummary: String?
}
