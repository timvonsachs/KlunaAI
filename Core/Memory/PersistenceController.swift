import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "KlunaAI",
            managedObjectModel: Self.makeManagedObjectModel()
        )
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }
        for description in container.persistentStoreDescriptions {
            description.setOption(
                true as NSNumber,
                forKey: NSMigratePersistentStoresAutomaticallyOption
            )
            description.setOption(
                true as NSNumber,
                forKey: NSInferMappingModelAutomaticallyOption
            )
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey
            )
        }

        var loadError: NSError?
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                loadError = error
            }
        }
        if let loadError {
            assertionFailure("CoreData load error: \(loadError)")
            print("❌ CoreData load error: \(loadError)")
            print("❌ CoreData details: domain=\(loadError.domain) code=\(loadError.code) userInfo=\(loadError.userInfo)")
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        func attribute(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = true,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            attr.defaultValue = defaultValue
            return attr
        }

        let session = NSEntityDescription()
        session.name = "CDSession"
        session.managedObjectClassName = NSStringFromClass(CDSession.self)
        session.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("date", .dateAttributeType),
            attribute("pitchType", .stringAttributeType),
            attribute("duration", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("overallScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("confidenceScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("energyScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("tempoScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("clarityScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("stabilityScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("charismaScore", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("featureZScoresData", .binaryDataAttributeType),
            attribute("transcription", .stringAttributeType),
            attribute("quickFeedback", .stringAttributeType),
            attribute("deepCoaching", .stringAttributeType),
            attribute("heatmapData", .binaryDataAttributeType),
            attribute("profileName", .stringAttributeType),
            attribute("profileRank", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("profileConfidence", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("dnaAuthority", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("dnaCharisma", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("dnaWarmth", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("dnaComposure", .floatAttributeType, optional: false, defaultValue: 0.0),
        ]

        let baseline = NSEntityDescription()
        baseline.name = "CDBaseline"
        baseline.managedObjectClassName = NSStringFromClass(CDBaseline.self)
        baseline.properties = [
            attribute("feature", .stringAttributeType),
            attribute("ewmaMean", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("ewmaVariance", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("sampleCount", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("lastUpdated", .dateAttributeType),
        ]

        let userProfile = NSEntityDescription()
        userProfile.name = "CDUserProfile"
        userProfile.managedObjectClassName = NSStringFromClass(CDUserProfile.self)
        userProfile.properties = [
            attribute("name", .stringAttributeType),
            attribute("language", .stringAttributeType),
            attribute("weeklyGoal", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("currentStreak", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("firstSessionDate", .dateAttributeType),
            attribute("longTermProfile", .stringAttributeType),
            attribute("strengthsData", .binaryDataAttributeType),
            attribute("weaknessesData", .binaryDataAttributeType),
            attribute("teamCode", .stringAttributeType),
            attribute("role", .stringAttributeType),
            attribute("voiceType", .stringAttributeType),
            attribute("goal", .stringAttributeType),
        ]

        let pitchType = NSEntityDescription()
        pitchType.name = "CDPitchType"
        pitchType.managedObjectClassName = NSStringFromClass(CDPitchType.self)
        pitchType.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("pitchDescription", .stringAttributeType),
            attribute("timeLimit", .integer32AttributeType, optional: false, defaultValue: 0),
            attribute("isCustom", .booleanAttributeType, optional: false, defaultValue: false),
            attribute("isDefault", .booleanAttributeType, optional: false, defaultValue: false),
        ]

        let challenge = NSEntityDescription()
        challenge.name = "CDChallenge"
        challenge.managedObjectClassName = NSStringFromClass(CDChallenge.self)
        challenge.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType),
            attribute("challengeDescription", .stringAttributeType),
            attribute("type", .stringAttributeType),
            attribute("target", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("progress", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("expiresAt", .dateAttributeType),
        ]

        let journalEntry = NSEntityDescription()
        journalEntry.name = "CDJournalEntry"
        journalEntry.managedObjectClassName = NSStringFromClass(CDJournalEntry.self)
        journalEntry.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("date", .dateAttributeType),
            attribute("duration", .doubleAttributeType, optional: false, defaultValue: 0.0),
            attribute("rawFeaturesJSON", .binaryDataAttributeType),
            attribute("mood", .stringAttributeType),
            attribute("transcription", .stringAttributeType),
            attribute("recordingURL", .stringAttributeType),
            attribute("audioRelativePath", .stringAttributeType),
            attribute("prompt", .stringAttributeType),
            attribute("arousal", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("acousticValence", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("quadrant", .stringAttributeType),
            attribute("moodLabel", .stringAttributeType),
            attribute("coachText", .stringAttributeType),
            attribute("themesRaw", .stringAttributeType),
            attribute("pillarVQ", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("pillarClarity", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("pillarDynamics", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("pillarRhythm", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("overallScore", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaArousal", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaValence", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("f0Mean", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("f0Range", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("jitter", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("shimmer", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("hnr", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("speechRate", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("pauseRate", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("loudnessMean", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("loudnessRange", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("flagsRaw", .stringAttributeType),
            attribute("warmth", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("stability", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("energy", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("tempo", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("openness", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("conversationId", .UUIDAttributeType),
            attribute("roundIndex", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("deltaEnergy", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaTension", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaFatigue", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaWarmth", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaExpressiveness", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("deltaTempo", .floatAttributeType, optional: false, defaultValue: 0.0),
            attribute("cardTitle", .stringAttributeType),
            attribute("cardRarity", .stringAttributeType),
            attribute("cardAtmosphereHex", .stringAttributeType),
            attribute("voiceObservation", .stringAttributeType),
        ]

        let conversation = NSEntityDescription()
        conversation.name = "CDConversation"
        conversation.managedObjectClassName = NSStringFromClass(CDConversation.self)
        conversation.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("roundCount", .integer16AttributeType, optional: false, defaultValue: 0),
            attribute("isComplete", .booleanAttributeType, optional: false, defaultValue: false),
            attribute("memorySummary", .stringAttributeType),
        ]

        model.entities = [session, baseline, userProfile, pitchType, challenge, journalEntry, conversation]
        return model
    }
}
