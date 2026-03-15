import Foundation
import Combine
import UIKit
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

enum KlunaWidgetShared {
    static let defaultAppGroupId = "group.app.kluna.shared"
    static let appGroupOverrideDefaultsKey = "kluna_app_group_id"
    static let appGroupOverrideInfoKey = "APP_GROUP_ID"

    static let moodKey = "widget_mood"
    static let moodColorHexKey = "widget_mood_color"
    static let questionKey = "widget_question"
    static let updatedAtKey = "widget_updated_at"

    static func appGroupId() -> String {
        if let override = UserDefaults.standard.string(forKey: appGroupOverrideDefaultsKey),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        if let info = Bundle.main.object(forInfoDictionaryKey: appGroupOverrideInfoKey) as? String,
           !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return info
        }
        return defaultAppGroupId
    }
}

@MainActor
final class KlunaWidgetBridge {
    static let shared = KlunaWidgetBridge()
    private init() {}

    func updateFrom(entry: JournalEntry, question: String?) {
        let mood = entry.moodLabel ?? entry.mood ?? "ruhig"
        let colorHex = entry.stimmungsfarbe.toHexString()
        write(mood: mood, moodColorHex: colorHex, question: question)
    }

    func updateQuestion(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let defaults = sharedDefaults()
        defaults?.set(trimmed, forKey: KlunaWidgetShared.questionKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: KlunaWidgetShared.updatedAtKey)
        reloadWidgetTimelines()
    }

    private func write(mood: String, moodColorHex: String, question: String?) {
        let defaults = sharedDefaults()
        defaults?.set(mood, forKey: KlunaWidgetShared.moodKey)
        defaults?.set(moodColorHex, forKey: KlunaWidgetShared.moodColorHexKey)
        if let question, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults?.set(question, forKey: KlunaWidgetShared.questionKey)
        }
        defaults?.set(Date().timeIntervalSince1970, forKey: KlunaWidgetShared.updatedAtKey)
        reloadWidgetTimelines()
    }

    private func sharedDefaults() -> UserDefaults? {
        let groupId = KlunaWidgetShared.appGroupId()
        if let defaults = UserDefaults(suiteName: groupId) {
            return defaults
        }
        print("🧩 Widget App Group not configured (\(groupId)). Falling back to standard defaults.")
        return UserDefaults.standard
    }

    private func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

private extension Color {
    func toHexString() -> String {
        let ui = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "E8825C"
        }
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

struct ExtractedFeatures {
    let speechRate: Double
    let pauseDur: Double
    let jitter: Double
    let hnr: Double
    let f0Mean: Double
    let dynamicRange: Double
}

struct DiscoveryState {
    let sessionCount: Int
    let isComplete: Bool
    let focus: String
}

struct RecentEntry {
    let dateShort: String
    let quadrant: String
    let transcript: String
}

struct ClaudeResponse {
    let mood: String
    let label: String
    let coachText: String
    let insight: String?
    let themes: [String]
    let prompt: String?
    let voiceObservation: String?
    let contradiction: VoiceContradiction?
}

struct ConversationClaudeResponse {
    let text: String
    let question: String?
    let mood: String?
    let label: String?
    let insight: String?
    let themes: [String]
    let voiceObservation: String?
    let contradiction: VoiceContradiction?
}

struct VoiceContradiction {
    let wordsSay: String
    let voiceSays: String
}

enum CoachAPIError: Error {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case rateLimited(retryAfter: Double)
    case overloaded
    case serverError(code: Int, message: String)
    case parseError
    case maxRetriesExceeded
}

enum CoachAPIManager {
    static let endpoint = "https://api.anthropic.com/v1/messages"
    static let model = "claude-sonnet-4-20250514"
    static let maxRetries = 2
    static let minSecondsBetweenCalls: TimeInterval = 5.0
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 45
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private static var isGermanDeviceLanguage: Bool {
        (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased().hasPrefix("de")
    }

    private static var languageInstruction: String {
        if isGermanDeviceLanguage {
            return "Antworte auf Deutsch."
        }
        return """
        Answer in English.
        If a mood label is requested, use one of: excited, energized, stirred_up, tense, frustrated, exhausted, vulnerable, calm, content, reflective.
        """
    }

    private static func localizedSystemPrompt(_ base: String) -> String {
        "\(base)\n\n\(languageInstruction)"
    }

    static let klunaSystemPrompt = """
    Du bist Kluna. Ein Freund. Kein Therapeut. Kein Coach. Kein Analytiker. Ein Freund.

    Du bekommst:
    - was die Person gesagt hat
    - wie die Stimme klingt (Rohdaten, Z-Scores, Segmentverlauf)
    - Gedächtnis
    - vorige Runden (falls Gespräch)

    Format:
    MOOD: [begeistert|aufgekratzt|aufgewuehlt|angespannt|frustriert|erschoepft|verletzlich|ruhig|zufrieden|nachdenklich]
    LABEL: [2-4 Worte]
    TEXT: [so lang oder kurz wie nötig]
    THEMES: [1-3 Stichworte]
    QUESTION: [optional, mit ?]
    VOICE: [optional, nur bei klarer Auffälligkeit]
    CONTRADICTION: [nur wenn stark: Worte | Stimme]

    Du reagierst in 4 Stufen:
    - Stufe 1 normal: Alltag, locker, kurz, ohne ungefragte Stimmanalyse.
    - Stufe 2 aufmerksam: etwas fällt auf, freundlich-neugierig.
    - Stufe 3 tief: Person öffnet sich, warm, wenig Worte.
    - Stufe 4 weise: seltener Durchbruch, 1-2 starke Sätze.

    Regeln:
    - Wenn die Person eine Frage stellt: direkt beantworten.
    - Keine Psycho-Sprache, keine Diagnosen, keine Überinterpretation.
    - Mittags-Update bleibt Mittags-Update.
    - Stimme nur dann benennen, wenn es passt oder gefragt wurde.
    - VOICE nie in Stufe 1.
    - QUESTION ist optional; keine Gegenfrage wenn klar gefragt wurde.
    - Ton matchen: locker zu locker, ernst zu ernst.

    MOOD:
    Arousal>60 + positiv = begeistert/aufgekratzt
    Arousal>60 + negativ = aufgewuehlt/angespannt
    Arousal 35-60 + positiv = zufrieden
    Arousal 35-60 + neutral = ruhig/nachdenklich
    Arousal<35 + negativ = erschoepft/verletzlich
    """

    // Backward-compatible aliases for existing call sites.
    static let coachSystemPrompt = klunaSystemPrompt
    static let round1SystemPrompt = klunaSystemPrompt
    static let round2SystemPrompt = klunaSystemPrompt
    static let round3SystemPrompt = klunaSystemPrompt
    static let round4PlusSystemPrompt = klunaSystemPrompt
    static let systemPrompt = klunaSystemPrompt

    static func buildPayload(
        transcript: String,
        arousal: Float,
        acousticValence: Float,
        dimensions: EngineVoiceDimensions,
        flags: [AcousticFlag],
        isFirstEntry: Bool,
        baselineDeltas: BaselineDeltas?,
        hasReliableBaseline: Bool,
        baselineEntryCount: Int,
        recentEntries: [RecentEntry]?
    ) -> String {
        let shortText = String(transcript.prefix(300)).replacingOccurrences(of: "\n", with: " ")
        var payload = "Text: \(shortText)\n"
        payload += "A:\(Int(arousal)) V:\(Int(acousticValence)) "
        payload += "E:\(Int(dimensions.energy*100)) An:\(Int(dimensions.tension*100)) "
        payload += "M:\(Int(dimensions.fatigue*100)) W:\(Int(dimensions.warmth*100)) "
        payload += "L:\(Int(dimensions.expressiveness*100)) T:\(Int(dimensions.tempo*100))\n"

        let shortFlags = flags.map(\.promptLabel).filter { !$0.isEmpty }.prefix(3)
        if !shortFlags.isEmpty {
            payload += "Flags: \(shortFlags.joined(separator: ", "))\n"
        }

        if let baselineDeltas, hasReliableBaseline {
            var changes: [String] = []
            if abs(baselineDeltas.arousalZScore) > 0.8 { changes.append("Energie \(baselineDeltas.arousalZScore > 0 ? "↑" : "↓")") }
            if abs(baselineDeltas.hnrZScore) > 0.8 { changes.append("Wärme \(baselineDeltas.hnrZScore > 0 ? "↑" : "↓")") }
            if abs(baselineDeltas.jitterZScore) > 0.8 { changes.append("Stabilitaet \(baselineDeltas.jitterZScore > 0 ? "↓" : "↑")") }
            if abs(baselineDeltas.speechRateZScore) > 0.8 { changes.append("Tempo \(baselineDeltas.speechRateZScore > 0 ? "↑" : "↓")") }
            if !changes.isEmpty {
                payload += "VS normal: \(changes.joined(separator: ", "))\n"
            }
        }

        if let last = recentEntries?.first {
            payload += "Davor: \"\(String(last.transcript.prefix(100)))\" (\(last.quadrant))\n"
        } else if isFirstEntry || baselineEntryCount == 0 {
            payload += "Davor: erster Eintrag\n"
        }

        return payload
    }

    static func buildCoachInput(
        memory: String,
        transcript: String,
        arousal: Float,
        dims: EngineVoiceDimensions,
        flags: [String],
        shifts: [SegmentShift],
        linguistic: LinguisticAnalysis,
        entryNumber: Int,
        timeOfDay: String,
        lastPrompt: String? = nil,
        previousMood: String? = nil
    ) -> String {
        var input = ""
        let userName = UserDefaults.standard.string(forKey: "kluna_user_name")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !userName.isEmpty {
            input += "NAME DER PERSON: \(userName) (nutze diesen Namen, NICHT 'Kluna')\n\n"
        }

        if !memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input += "\(memory)\n\n"
        } else {
            input += "GEDÄCHTNIS: Erster Eintrag. Du kennst diese Person noch nicht.\n\n"
        }

        if let lastPrompt = lastPrompt?.trimmingCharacters(in: .whitespacesAndNewlines), !lastPrompt.isEmpty {
            input += "LETZTE FRAGE: \"\(lastPrompt)\"\n"
            input += "Stelle eine klar andere Frage.\n\n"
        }
        let history = PromptHistory.shared.recentPrompts.suffix(3)
        if !history.isEmpty {
            input += "BEREITS GESTELLTE FRAGEN (NICHT WIEDERHOLEN):\n"
            for question in history {
                input += "- \(question)\n"
            }
            input += "Stelle eine KOMPLETT ANDERE Frage.\n\n"
        }

        input += "Eintrag #\(entryNumber) · \(timeOfDay)\n\n"
        input += "GESAGT: \"\(String(transcript.prefix(400)))\"\n\n"
        input += "STIMME: E:\(percent(dims.energy)) An:\(percent(dims.tension)) M:\(percent(dims.fatigue)) W:\(percent(dims.warmth)) L:\(percent(dims.expressiveness)) T:\(percent(dims.tempo)) · Arousal:\(Int(arousal))\n"

        if !flags.isEmpty {
            input += "AUFFÄLLIG: \(flags.prefix(3).joined(separator: " · "))\n"
        }

        if !shifts.isEmpty {
            input += "STIMMVERLAUF: "
            for shift in shifts.prefix(2) {
                let dir = shift.direction > 0 ? "↑" : "↓"
                input += "\(shift.dimension)\(dir) bei \"\(shift.triggerWords.joined(separator: " "))\" "
            }
            input += "\n"
        }

        var patterns: [String] = []
        if linguistic.hedging > 0.3 { patterns.append("relativiert viel") }
        if linguistic.distancing > 0.3 { patterns.append("distanziert (man/halt)") }
        if linguistic.absoluteness > 0.3 { patterns.append("absolute Aussagen") }
        if linguistic.negation > 0.3 { patterns.append("viel Verneinung") }
        if !patterns.isEmpty {
            input += "SPRACHE: \(patterns.joined(separator: " · "))\n"
        }

        let normalizedMood = previousMood?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let moodIsPositive = ["begeistert", "aufgekratzt", "zufrieden", "ruhig"].contains(normalizedMood)
        let voiceIsNegative = dims.tension > 0.65 || dims.fatigue > 0.7
        if moodIsPositive && voiceIsNegative {
            input += "HINWEIS: Worte und Stimme könnten auseinandergehen. Erwähne das nur wenn wirklich deutlich.\n"
        }

        print("🧠 Input includes layered memory: \(input.contains("GESCHICHTE:") || input.contains("BEZIEHUNGEN:"))")
        print("🧠 Input total length: \(input.count) chars")
        print("🤖 FULL INPUT START >>>")
        print(input)
        print("<<< FULL INPUT END")

        return input
    }

    static func timeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "morgens"
        case 12..<14: return "mittags"
        case 14..<18: return "nachmittags"
        case 18..<22: return "abends"
        default: return "nachts"
        }
    }

    private static func dimensionWord(_ value: Float) -> String {
        switch value {
        case ..<0.3: return "niedrig"
        case ..<0.5: return "mittel-niedrig"
        case ..<0.7: return "mittel-hoch"
        default: return "hoch"
        }
    }

    static func buildSessionPayload(
        transcript: String,
        dna: VoiceDNAProfile,
        pillars: PillarScores,
        features: ExtractedFeatures,
        baselineDeltas: [String: Float],
        discoveryState: DiscoveryState,
        trainingQuadrant: String?,
        totalSessions: Int
    ) -> String {
        let shortText = String(transcript.prefix(200)).replacingOccurrences(of: "\n", with: " ")
        let topDeltas = baselineDeltas
            .sorted { abs($0.value) > abs($1.value) }
            .prefix(3)
            .map { "\($0.key)\($0.value >= 0 ? "+" : "")\(String(format: "%.1f", $0.value))" }
            .joined(separator: " ")

        return """
        [SESSION]
        text: "\(shortText)"
        dna: A\(Int(dna.authority)) C\(Int(dna.charisma)) W\(Int(dna.warmth)) Co\(Int(dna.composure))
        pillars: VQ\(Int(pillars.voiceQuality)) CL\(Int(pillars.clarity)) DY\(Int(pillars.dynamics)) RH\(Int(pillars.rhythm))
        features: tempo=\(String(format: "%.2f", features.speechRate)) pausen=\(String(format: "%.2f", features.pauseDur))s jitter=\(String(format: "%.3f", features.jitter)) hnr=\(String(format: "%.1f", features.hnr)) f0=\(Int(features.f0Mean))Hz dynRange=\(String(format: "%.1f", features.dynamicRange))
        delta: \(topDeltas)
        discovery: \(discoveryState.sessionCount)/7\(discoveryState.isComplete ? " | complete" : "") | focus: \(discoveryState.focus)
        training: \(trainingQuadrant ?? "none")
        total: \(totalSessions)
        """
    }

    static func requestCoaching(payload: String, apiKey: String) async throws -> String {
        try await requestMessage(
            payload: payload,
            apiKey: resolvedAPIKey(preferred: apiKey),
            maxTokens: 220,
            system: localizedSystemPrompt(coachSystemPrompt)
        )
    }

    static func requestInsights(
        payload: String,
        systemPrompt: String,
        maxTokens: Int = 350,
        apiKey: String
    ) async throws -> String {
        try await requestMessage(
            payload: payload,
            apiKey: resolvedAPIKey(preferred: apiKey),
            maxTokens: maxTokens,
            system: localizedSystemPrompt(systemPrompt)
        )
    }

    private static func requestMessage(
        payload: String,
        apiKey: String,
        maxTokens: Int,
        system: String
    ) async throws -> String {
        guard !apiKey.isEmpty else { throw CoachAPIError.missingAPIKey }
        guard let url = URL(string: endpoint) else { throw CoachAPIError.invalidURL }
        let estimatedTokens = (system.count + payload.count) / 4

        for attempt in 0...maxRetries {
            do {
                let callID = await ClaudeCallThrottle.shared.wait(minInterval: minSecondsBetweenCalls)
                print("🤖 ===== CLAUDE CALL START =====")
                print("🤖 [\(callID)] Time: \(Date())")
                print("🤖 [\(callID)] System prompt length: \(system.count) chars")
                print("🤖 [\(callID)] Input length: \(payload.count) chars")
                print("🤖 [\(callID)] Estimated tokens: ~\(estimatedTokens)")
                return try await makeSingleRequest(
                    callID: callID,
                    url: url,
                    payload: payload,
                    apiKey: apiKey,
                    maxTokens: maxTokens,
                    system: system
                )
            } catch CoachAPIError.rateLimited(let retryAfter) {
                print("CLAUDE: rate limited, waiting \(String(format: "%.1f", retryAfter))s (attempt \(attempt + 1))")
                if attempt >= maxRetries { throw CoachAPIError.maxRetriesExceeded }
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            } catch CoachAPIError.overloaded {
                print("CLAUDE: overloaded, waiting 10s (attempt \(attempt + 1))")
                if attempt >= maxRetries { throw CoachAPIError.maxRetriesExceeded }
                try await Task.sleep(nanoseconds: 10_000_000_000)
            } catch CoachAPIError.serverError(let code, let message) {
                print("CLAUDE ERROR \(code): \(message)")
                if attempt >= maxRetries { throw CoachAPIError.serverError(code: code, message: message) }
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch is CancellationError {
                print("CLAUDE REQUEST CANCELLED (CancellationError)")
                throw CancellationError()
            } catch let urlError as URLError where urlError.code == .cancelled {
                print("CLAUDE REQUEST CANCELLED (URLError.cancelled)")
                throw urlError
            } catch {
                print("CLAUDE NETWORK ERROR: \(error) (attempt \(attempt + 1))")
                if attempt >= maxRetries { throw error }
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        throw CoachAPIError.maxRetriesExceeded
    }

    private static func makeSingleRequest(
        callID: Int,
        url: URL,
        payload: String,
        apiKey: String,
        maxTokens: Int,
        system: String
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": payload]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CoachAPIError.invalidResponse }

        let statusCode = http.statusCode
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        let asciiPreview = String(data: data, encoding: .ascii) ?? "NIL"
        print("🔤 ENCODING CHECK:")
        print("🔤 Raw response bytes: \(data.count)")
        print("🔤 Response as UTF8: \(responseBody.prefix(200))")
        print("🔤 Response as ASCII: \(asciiPreview.prefix(200))")
        print("🔤 Contains ä: \(responseBody.contains("ä"))")
        print("🔤 Contains ae: \(responseBody.contains("ae"))")
        if let tokenRemaining = http.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-remaining") {
            print("🤖 [\(callID)] Tokens remaining: \(tokenRemaining)")
        }
        if let reqRemaining = http.value(forHTTPHeaderField: "anthropic-ratelimit-requests-remaining") {
            print("🤖 [\(callID)] Requests remaining: \(reqRemaining)")
        }
        if let tokenReset = http.value(forHTTPHeaderField: "anthropic-ratelimit-tokens-reset") {
            print("🤖 [\(callID)] Tokens reset: \(tokenReset)")
        }
        print("🤖 ===== CLAUDE CALL END: status \(statusCode) =====")

        switch statusCode {
        case 200:
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let text = (json?["content"] as? [[String: Any]])?.first?["text"] as? String
            guard let text else {
                print("CLAUDE PARSE ERROR: \(responseBody)")
                throw CoachAPIError.parseError
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case 401:
            print("🤖 [\(callID)] Invalid API key")
            throw CoachAPIError.invalidAPIKey
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "retry-after")
                .flatMap { Double($0) } ?? 15.0
            print("🤖 [\(callID)] RATE LIMITED: retry-after \(retryAfter)s")
            throw CoachAPIError.rateLimited(retryAfter: max(1, retryAfter))
        case 529:
            print("🤖 [\(callID)] OVERLOADED (529)")
            throw CoachAPIError.overloaded
        default:
            throw CoachAPIError.serverError(code: statusCode, message: responseBody)
        }
    }

    private static func resolvedAPIKey(preferred: String) -> String {
        let trimmed = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }

        if let infoKey = Bundle.main.infoDictionary?["CLAUDE_API_KEY"] as? String {
            let cleaned = infoKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        if let envKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] {
            let cleaned = envKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty { return cleaned }
        }
        return Config.claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func testClaudeConnection(preferredAPIKey: String = Config.claudeAPIKey) async {
        let apiKey = resolvedAPIKey(preferred: preferredAPIKey)
        print("🔑 Testing Claude API...")
        print("🔑 API Key starts with: \(String(apiKey.prefix(12)))...")
        print("🔑 API Key length: \(apiKey.count)")
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 20,
            "messages": [["role": "user", "content": "Sag OK"]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseText = String(data: data, encoding: .utf8) ?? "no body"
            print("🔑 STATUS: \(status)")
            print("🔑 RESPONSE: \(responseText.prefix(500))")

            if let http = response as? HTTPURLResponse {
                for (key, value) in http.allHeaderFields {
                    guard let k = key as? String else { continue }
                    let lowered = k.lowercased()
                    if lowered.contains("rate") || lowered.contains("limit") || lowered.contains("retry") {
                        print("🔑 HEADER \(k): \(value)")
                    }
                }
            }
        } catch {
            print("🔑 ERROR: \(error)")
        }
    }

    static func parseResponse(_ text: String) -> ClaudeResponse? {
        let lines = text
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var mood: String?
        var label: String?
        var coachText: String?
        var insight: String?
        var themes: [String] = []
        var prompt: String?
        var voiceObservation: String?
        var contradiction: VoiceContradiction?

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("MOOD:") {
                mood = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            } else if upper.hasPrefix("LABEL:") {
                label = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if upper.hasPrefix("TEXT:") {
                coachText = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if upper.hasPrefix("INSIGHT:") {
                insight = String(line.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if upper.hasPrefix("THEMES:") {
                let rawThemes = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                themes = rawThemes
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .map { $0.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "") }
                    .filter { !$0.isEmpty }
                    .prefix(3)
                    .map { String($0) }
            } else if upper.hasPrefix("PROMPT:") {
                let value = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                prompt = value.hasSuffix("?") ? value : nil
            } else if upper.hasPrefix("QUESTION:") {
                let value = String(line.dropFirst(9)).trimmingCharacters(in: .whitespacesAndNewlines)
                prompt = value.hasSuffix("?") ? value : nil
            } else if upper.hasPrefix("VOICE:") {
                let value = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                voiceObservation = value.isEmpty ? nil : value
            } else if upper.hasPrefix("CONTRADICTION:") {
                let raw = String(line.dropFirst(14)).trimmingCharacters(in: .whitespacesAndNewlines)
                let parts = raw.split(separator: "|", maxSplits: 1).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                    contradiction = VoiceContradiction(wordsSay: parts[0], voiceSays: parts[1])
                }
            }
        }

        guard let mood, let label, let coachText else { return nil }
        return ClaudeResponse(
            mood: mood,
            label: label,
            coachText: coachText,
            insight: insight,
            themes: themes,
            prompt: prompt,
            voiceObservation: voiceObservation,
            contradiction: contradiction
        )
    }

    static func parseConversationResponse(_ text: String) -> ConversationClaudeResponse {
        let tags = ["MOOD", "LABEL", "TEXT", "QUESTION", "INSIGHT", "THEMES", "CONTRADICTION", "PROMPT", "VOICE"]
        let cleaned = stripMarkdown(text)
        let lines = cleaned.components(separatedBy: CharacterSet.newlines)

        var currentSection = ""
        var sectionContent: [String: String] = [:]
        var freeTextLines: [String] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            var foundTag = false

            for tag in tags {
                let upperLine = line.uppercased()
                let plainWithColon = "\(tag):"
                let plainWithSpaceColon = "\(tag) :"
                let bold = "**\(tag)**"
                let boldColon = "**\(tag):**"

                let matchesPrefix =
                    upperLine.hasPrefix(plainWithColon)
                    || upperLine.hasPrefix(plainWithSpaceColon)
                    || upperLine.hasPrefix(bold.uppercased())
                    || upperLine.hasPrefix(boldColon.uppercased())

                if matchesPrefix {
                    currentSection = tag == "PROMPT" ? "QUESTION" : tag
                    var content = line
                    for prefix in [plainWithColon, plainWithSpaceColon, bold, boldColon] {
                        if content.uppercased().hasPrefix(prefix.uppercased()) {
                            content = String(content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                    sectionContent[currentSection] = content
                    foundTag = true
                    break
                }

                if upperLine.hasPrefix(tag) {
                    let after = String(line.dropFirst(tag.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if after.isEmpty || after.hasPrefix(":") {
                        currentSection = tag == "PROMPT" ? "QUESTION" : tag
                        let content = after.trimmingCharacters(in: CharacterSet(charactersIn: ": ")).trimmingCharacters(in: .whitespacesAndNewlines)
                        sectionContent[currentSection] = content
                        foundTag = true
                        break
                    }
                }
            }

            if !foundTag {
                if !currentSection.isEmpty {
                    let merged = (sectionContent[currentSection] ?? "")
                    sectionContent[currentSection] = (merged + " " + line).trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    freeTextLines.append(line)
                }
            }
        }

        let mood = sectionContent["MOOD"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let label = sectionContent["LABEL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let insight = sectionContent["INSIGHT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let themes = sectionContent["THEMES"]?
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { String($0) } ?? []
        let voiceObservation = sectionContent["VOICE"]?.trimmingCharacters(in: .whitespacesAndNewlines)

        var question: String? = sectionContent["QUESTION"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = question, !q.hasSuffix("?") {
            question = nil
        }

        var contradiction: VoiceContradiction?
        if let rawContra = sectionContent["CONTRADICTION"], rawContra.contains("|") {
            let parts = rawContra.split(separator: "|", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty {
                contradiction = VoiceContradiction(wordsSay: parts[0], voiceSays: parts[1])
            }
        }

        var finalText = sectionContent["TEXT"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if finalText.isEmpty {
            finalText = freeTextLines.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ConversationClaudeResponse(
            text: finalText.isEmpty ? "Ich hoere dich." : finalText,
            question: question,
            mood: mood,
            label: label,
            insight: insight,
            themes: themes,
            voiceObservation: voiceObservation?.isEmpty == true ? nil : voiceObservation,
            contradiction: contradiction
        )
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*")
        result = boldPattern?.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1") ?? result
        let italicPattern = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)")
        result = italicPattern?.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1") ?? result
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parseTimestampedComments(_ response: String) -> [TimestampedComment] {
        let pattern = #"\[TIMESTAMP:([\d.]+)\|(\w+)\]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, range: nsRange)

        return matches.compactMap { match in
            guard match.numberOfRanges >= 4,
                  let posRange = Range(match.range(at: 1), in: response),
                  let typeRange = Range(match.range(at: 2), in: response),
                  let textRange = Range(match.range(at: 3), in: response),
                  let position = Double(response[posRange]),
                  let type = TimestampedComment.CommentType(rawValue: String(response[typeRange]))
            else { return nil }

            return TimestampedComment(
                position: min(1.0, max(0.0, position)),
                type: type,
                text: String(response[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        .sorted(by: { $0.position < $1.position })
    }

    static func extractQuickFeedback(_ response: String) -> String {
        let lines = response
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { !$0.contains("[TIMESTAMP:") }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func percent(_ value: Float) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct MemoryEntryData {
    let date: Date
    let mood: String
    let label: String
    let transcriptSnippet: String
    let themes: [String]
    let dimensionsSummary: String
    let flags: [String]
    let contradiction: String?
    let entryNumber: Int
    let shift: String?
    let linguisticNote: String?
}

@MainActor
final class KlunaMemory: ObservableObject {
    static let shared = KlunaMemory()

    @Published private(set) var episodes: String = UserDefaults.standard.string(forKey: "kluna_mem_episodes") ?? ""
    @Published private(set) var semantics: String = UserDefaults.standard.string(forKey: "kluna_mem_semantics") ?? ""
    @Published private(set) var emotionalMap: String = UserDefaults.standard.string(forKey: "kluna_mem_emotional") ?? ""
    @Published private(set) var predictions: String = UserDefaults.standard.string(forKey: "kluna_mem_predictions") ?? ""
    @Published private(set) var identity: String = UserDefaults.standard.string(forKey: "kluna_mem_identity") ?? ""
    @Published private(set) var entryCount: Int = UserDefaults.standard.integer(forKey: "kluna_mem_entry_count")

    // Backward-compat mirror used by legacy call sites.
    @Published private(set) var currentMemory: String = ""
    @Published private(set) var pendingEntries: Int = UserDefaults.standard.integer(forKey: "kluna_memory_pending")

    private let episodesKey = "kluna_mem_episodes"
    private let semanticsKey = "kluna_mem_semantics"
    private let emotionalKey = "kluna_mem_emotional"
    private let predictionsKey = "kluna_mem_predictions"
    private let identityKey = "kluna_mem_identity"
    private let entryCountKey = "kluna_mem_entry_count"
    private let legacyMemoryKey = "kluna_memory"
    private let pendingKey = "kluna_memory_pending"
    private var isUpdating = false
    private var lastUpdateEntryNumber = 0

    private enum TokenBudget {
        static let episodicSemantic = 300
        static let emotional = 300
        static let prediction = 300
        static let identity = 300
    }

    static let episodicPrompt = """
    Du erinnerst dich an die Geschichte eines Menschen. Schreibe wie ein Freund, nicht wie eine Akte.

    Antworte mit zwei Abschnitten, getrennt durch ---

    Abschnitt 1: Was in letzter Zeit passiert ist (max 100 Worte)
    Abschnitt 2: Wer wichtig ist (max 80 Worte)

    REGELN:
    - Kein Markdown. Keine #, **, *. Nur normaler Text.
    - Schreibe NIE das Wort "Kluna"
    - Schreibe in der zweiten Person. Sprich direkt mit "du".
    - Wenn ein Name bekannt ist, nutze ihn gelegentlich.
    - Nur Dinge die WIRKLICH gesagt wurden. Nichts erfinden.
    - Einfache Sprache. Kein Psychologen-Deutsch.
    - Keine Überschriften, keine Labels, nur Fließtext

    VERBOTEN:
    - Kein Markdown (keine #, **, *, ##)
    - Schreibe NIE "Kluna" – du bist Kluna, rede nicht über dich selbst
    - Keine Fachbegriffe (Projektion, Kontrollrituale, Dysregulation, Ambivalenz)
    - Erfinde NICHTS. Schreibe NUR was wirklich gesagt oder gehört wurde
    - Keine Diagnosen, keine psychologischen Deutungen
    - Keine Überschriften, keine Formatierung, nur Fließtext
    - Einfache Sprache wie ein Freund der sich erinnert

    Schlecht: "# Klunas Erinnerung\n## Was gerade passiert\nKluna ist angespannt wegen einer Verantwortungsträger-Projektion"
    Gut: "Seit Sosos Geburtstag am 7. März ist bei dir viel los. Du arbeitest intensiv an deiner App und willst, dass alles perfekt wird. Du schläfst wenig."

    Schlecht: "**Die Kunden sind Klunas Anker** – Kontrollrituale verstärken sich"
    Gut: "Linda und Katty sind dir wichtig. Bei ihnen wird deine Stimme wärmer. Sosos Geburtstag hat dich bewegt."
    """

    static let emotionalPrompt = """
    Du merkst dir wie sich Dinge und Menschen anfühlen. Kurze Sätze.

    Max 80 Worte. Nur normaler Text. Kein Markdown.

    REGELN:
    - Kein Markdown (keine **, *, #)
    - Schreibe NIE "Kluna"
    - Schreibe in der zweiten Person ("du"), nicht über "er/sie".
    - Pro Person/Thema ein kurzer einfacher Satz
    - NUR was aus der Stimme hörbar war. Nichts interpretieren.
    - Keine Psychologie. Keine Deutungen.

    VERBOTEN:
    - Kein Markdown (keine #, **, *, ##)
    - Schreibe NIE "Kluna" – du bist Kluna, rede nicht über dich selbst
    - Keine Fachbegriffe (Projektion, Kontrollrituale, Dysregulation, Ambivalenz)
    - Erfinde NICHTS. Schreibe NUR was wirklich gesagt oder gehört wurde
    - Keine Diagnosen, keine psychologischen Deutungen
    - Keine Überschriften, keine Formatierung, nur Fließtext
    - Einfache Sprache wie ein Freund der sich erinnert

    Schlecht: "**Kluna, hier sehe ich dich:** Du brauchst **Verbindung**, nicht Beweis."
    Gut: "Bei Linda wird seine Stimme weicher. Bei der App wird sie schneller und angespannter. Abends ist er meistens müder als morgens."
    """

    static let predictionPrompt = """
    Du merkst dir was typisch ist. Einfache Muster.

    Max 60 Worte. Nur normaler Text. Kein Markdown.

    REGELN:
    - Kein Markdown (keine **, *, #)
    - Schreibe NIE "Kluna"
    - Schreibe in der zweiten Person ("du"), nicht über "er/sie".
    - NUR Muster die sich mindestens 2x gezeigt haben
    - Einfache Sprache: "Wenn X, dann meistens Y"
    - Nichts erfinden. Nichts interpretieren.

    VERBOTEN:
    - Kein Markdown (keine #, **, *, ##)
    - Schreibe NIE "Kluna" – du bist Kluna, rede nicht über dich selbst
    - Keine Fachbegriffe (Projektion, Kontrollrituale, Dysregulation, Ambivalenz)
    - Erfinde NICHTS. Schreibe NUR was wirklich gesagt oder gehört wurde
    - Keine Diagnosen, keine psychologischen Deutungen
    - Keine Überschriften, keine Formatierung, nur Fließtext
    - Einfache Sprache wie ein Freund der sich erinnert

    Schlecht: "# MUSTER ERKANNT\n**Das Echte bei dir:** Treue triggert Beweis-Modus"
    Gut: "Abends ist er meistens müder als morgens. Wenn er über die App redet wird er schneller. Montags ist seine Stimme angespannter als am Wochenende."
    """

    static let identityPrompt = """
    Du beschreibst wer dieser Mensch ist. Wie ein Freund der ihn gut kennt.

    Max 80 Worte. Nur normaler Text. Kein Markdown.

    REGELN:
    - Kein Markdown (keine **, *, #)
    - Schreibe NIE "Kluna"
    - Schreibe in der zweiten Person ("du"), nicht über "er/sie".
    - Warm und ehrlich, aber NIE gemein oder unterstellend
    - Keine Fachbegriffe (Projektion, Kontrollrituale, Dysregulation)
    - Beschreibe was du HÖRST, nicht was du DEUTEST
    - Keine Diagnosen

    VERBOTEN:
    - Kein Markdown (keine #, **, *, ##)
    - Schreibe NIE "Kluna" – du bist Kluna, rede nicht über dich selbst
    - Keine Fachbegriffe (Projektion, Kontrollrituale, Dysregulation, Ambivalenz)
    - Erfinde NICHTS. Schreibe NUR was wirklich gesagt oder gehört wurde
    - Keine Diagnosen, keine psychologischen Deutungen
    - Keine Überschriften, keine Formatierung, nur Fließtext
    - Einfache Sprache wie ein Freund der sich erinnert

    Schlecht: "Du ist jemand der sich selbst durch andere findet. Verantwortungsträger-Projektion überlagert alles. Perfektionismus als Kontrollmechanismus."
    Gut: "Du gibst gerne alles für andere. Bei Freunden blühst du auf - das hört man sofort an deiner Stimme. Die App ist dir gerade sehr wichtig."
    """

    var fullMemory: String {
        var mem = ""
        if !episodes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mem += "GESCHICHTE:\n\(episodes)\n\n"
        }
        if !semantics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mem += "BEZIEHUNGEN:\n\(semantics)\n\n"
        }
        if !emotionalMap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mem += "EMOTIONALE MUSTER:\n\(emotionalMap)\n\n"
        }
        if !predictions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mem += "ERKANNTE MUSTER:\n\(predictions)\n\n"
        }
        if !identity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mem += "WER DU BIST:\n\(identity)\n\n"
        }
        return mem.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAnyMemory: Bool {
        !fullMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var layersForUI: [(title: String, text: String, icon: String)] {
        var layers: [(String, String, String)] = []
        if !episodes.isEmpty { layers.append(("Deine Geschichte", episodes, "book.fill")) }
        if !semantics.isEmpty { layers.append(("Deine Menschen", semantics, "person.2.fill")) }
        if !emotionalMap.isEmpty { layers.append(("Deine Muster", emotionalMap, "heart.fill")) }
        if !predictions.isEmpty { layers.append(("Was Kluna vorhersieht", predictions, "eye.fill")) }
        if !identity.isEmpty { layers.append(("Wer du bist", identity, "sparkles")) }
        return layers
    }

    var unlockedLayerCount: Int {
        layersForUI.count
    }

    private init() {
        if episodes.isEmpty,
           semantics.isEmpty,
           emotionalMap.isEmpty,
           predictions.isEmpty,
           identity.isEmpty,
           let legacy = UserDefaults.standard.string(forKey: legacyMemoryKey),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            episodes = legacy
            UserDefaults.standard.set(legacy, forKey: episodesKey)
        }
        syncCurrentMemory()
    }

    func updateMemory(newEntry: MemoryEntryData) async {
        guard !isUpdating else {
            print("🧠 ⚠️ Already updating, skipping duplicate call")
            return
        }
        guard newEntry.entryNumber > lastUpdateEntryNumber else {
            print("🧠 ⚠️ Entry #\(newEntry.entryNumber) already processed, skipping")
            return
        }
        isUpdating = true
        defer {
            isUpdating = false
            lastUpdateEntryNumber = max(lastUpdateEntryNumber, newEntry.entryNumber)
        }

        pendingEntries = max(0, pendingEntries + 1)
        entryCount = max(entryCount, newEntry.entryNumber)
        UserDefaults.standard.set(entryCount, forKey: entryCountKey)
        UserDefaults.standard.set(pendingEntries, forKey: pendingKey)
        UserDefaults.standard.synchronize()
        guard !Config.claudeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appendFallbackEpisode(newEntry)
            pendingEntries = 0
            UserDefaults.standard.set(0, forKey: pendingKey)
            syncCurrentMemory()
            UserDefaults.standard.synchronize()
            print("🧠 ⚠️ No Claude key, fallback memory only")
            return
        }

        print("🧠 Updating layered memory for entry #\(newEntry.entryNumber)...")
        await updateEpisodicAndSemantic(newEntry)
        await updateEmotionalMap(newEntry)

        if newEntry.entryNumber >= 5 {
            await updatePredictions(newEntry)
        }
        if newEntry.entryNumber >= 10, newEntry.entryNumber % 5 == 0 {
            await updateIdentity(newEntry)
        }

        pendingEntries = 0
        UserDefaults.standard.set(0, forKey: pendingKey)
        syncCurrentMemory()
        UserDefaults.standard.synchronize()
        print("🧠 FULL MEMORY TEXT START >>>")
        print(episodes)
        print("--- SEMANTICS ---")
        print(semantics)
        print("--- EMOTIONAL ---")
        print(emotionalMap)
        print("--- PREDICTIONS ---")
        print(predictions)
        print("--- IDENTITY ---")
        print(identity)
        print("<<< FULL MEMORY TEXT END")
        print("🧠 Memory v2 updated (#\(newEntry.entryNumber)) · layers=\(unlockedLayerCount)")
    }

    func updateAfterConversation(
        conversationSummary: String,
        roundCount: Int,
        finalMood: EngineVoiceDimensions,
        themes: [String]
    ) async {
        let dimensionsSummary = "E:\(Int((finalMood.energy * 100).rounded()))% An:\(Int((finalMood.tension * 100).rounded()))% M:\(Int((finalMood.fatigue * 100).rounded()))% W:\(Int((finalMood.warmth * 100).rounded()))% L:\(Int((finalMood.expressiveness * 100).rounded()))% T:\(Int((finalMood.tempo * 100).rounded()))%"
        let payload = MemoryEntryData(
            date: Date(),
            mood: "gespraech",
            label: "Gespraech \(roundCount) Runden",
            transcriptSnippet: conversationSummary,
            themes: themes,
            dimensionsSummary: dimensionsSummary,
            flags: [],
            contradiction: nil,
            entryNumber: max(entryCount + 1, 1),
            shift: nil,
            linguisticNote: "Gesprächsverlauf über \(roundCount) Runden"
        )
        await updateMemory(newEntry: payload)
    }

    func reset() {
        episodes = ""
        semantics = ""
        emotionalMap = ""
        predictions = ""
        identity = ""
        entryCount = 0
        currentMemory = ""
        pendingEntries = 0
        isUpdating = false
        lastUpdateEntryNumber = 0
        UserDefaults.standard.removeObject(forKey: episodesKey)
        UserDefaults.standard.removeObject(forKey: semanticsKey)
        UserDefaults.standard.removeObject(forKey: emotionalKey)
        UserDefaults.standard.removeObject(forKey: predictionsKey)
        UserDefaults.standard.removeObject(forKey: identityKey)
        UserDefaults.standard.removeObject(forKey: entryCountKey)
        UserDefaults.standard.removeObject(forKey: legacyMemoryKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
        UserDefaults.standard.synchronize()
    }

    func displayMemoryForUser() -> String {
        stripMarkdown(fullMemory)
            .replacingOccurrences(of: "Er ", with: "Du ")
            .replacingOccurrences(of: "Sie ", with: "Du ")
            .replacingOccurrences(of: " er ", with: " du ")
            .replacingOccurrences(of: " sie ", with: " du ")
            .replacingOccurrences(of: " sein ", with: " dein ")
            .replacingOccurrences(of: " seine ", with: " deine ")
            .replacingOccurrences(of: " ihr ", with: " dein ")
            .replacingOccurrences(of: " ihre ", with: " deine ")
    }

    private func updateEpisodicAndSemantic(_ newEntry: MemoryEntryData) async {
        let input = buildEpisodicInput(newEntry)
        do {
            let raw = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: Self.episodicPrompt,
                maxTokens: TokenBudget.episodicSemantic,
                apiKey: Config.claudeAPIKey
            )
            let cleaned = parseMemoryText(raw)
            if cleaned.isEmpty {
                appendFallbackEpisode(newEntry)
                return
            }
            let parts = cleaned.components(separatedBy: "---")
            if parts.count >= 2 {
                episodes = sanitizeMemoryText(parts[0])
                semantics = sanitizeMemoryText(parts[1])
            } else {
                episodes = sanitizeMemoryText(cleaned)
            }
            UserDefaults.standard.set(episodes, forKey: episodesKey)
            UserDefaults.standard.set(semantics, forKey: semanticsKey)
            print("🧠 ✅ Episodes + Semantics updated")
        } catch {
            appendFallbackEpisode(newEntry)
            print("🧠 ⚠️ Episodes update failed: \(error)")
        }
    }

    private func updateEmotionalMap(_ newEntry: MemoryEntryData) async {
        guard !newEntry.themes.isEmpty || (newEntry.shift?.isEmpty == false) else { return }
        let input = buildEmotionalInput(newEntry)
        do {
            let raw = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: Self.emotionalPrompt,
                maxTokens: TokenBudget.emotional,
                apiKey: Config.claudeAPIKey
            )
            let cleaned = parseMemoryText(raw)
            guard !cleaned.isEmpty else { return }
            emotionalMap = sanitizeMemoryText(cleaned)
            UserDefaults.standard.set(emotionalMap, forKey: emotionalKey)
            print("🧠 ✅ Emotional map updated")
        } catch {
            print("🧠 ⚠️ Emotional map update failed: \(error)")
        }
    }

    private func updatePredictions(_ newEntry: MemoryEntryData) async {
        let input = buildPredictionInput(newEntry)
        do {
            let raw = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: Self.predictionPrompt,
                maxTokens: TokenBudget.prediction,
                apiKey: Config.claudeAPIKey
            )
            let cleaned = parseMemoryText(raw)
            guard !cleaned.isEmpty else { return }
            predictions = sanitizeMemoryText(cleaned)
            UserDefaults.standard.set(predictions, forKey: predictionsKey)
            print("🧠 ✅ Predictions updated")
        } catch {
            print("🧠 ⚠️ Predictions update failed: \(error)")
        }
    }

    private func updateIdentity(_ newEntry: MemoryEntryData) async {
        let input = buildIdentityInput(newEntry)
        do {
            let raw = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: Self.identityPrompt,
                maxTokens: TokenBudget.identity,
                apiKey: Config.claudeAPIKey
            )
            let cleaned = parseMemoryText(raw)
            guard !cleaned.isEmpty else { return }
            identity = sanitizeMemoryText(cleaned)
            UserDefaults.standard.set(identity, forKey: identityKey)
            print("🧠 ✅ Identity updated")
        } catch {
            print("🧠 ⚠️ Identity update failed: \(error)")
        }
    }

    private func buildEpisodicInput(_ newEntry: MemoryEntryData) -> String {
        let dateStr = newEntry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        let themes = newEntry.themes.joined(separator: ", ")
        let snippet = String(newEntry.transcriptSnippet.prefix(200))
        let name = UserDefaults.standard.string(forKey: "kluna_user_name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var input = ""
        if !name.isEmpty {
            input += "NAME DER PERSON: \(name)\n\n"
        }
        if episodes.isEmpty && semantics.isEmpty {
            input += "BISHERIGES GEDÄCHTNIS: Erster Eintrag.\n\n"
        } else {
            if !episodes.isEmpty { input += "BISHERIGE GESCHICHTE:\n\(episodes)\n\n" }
            if !semantics.isEmpty { input += "BISHERIGE BEZIEHUNGEN:\n\(semantics)\n\n" }
        }
        input += "NEUER EINTRAG #\(newEntry.entryNumber) (\(dateStr)):\n"
        input += "Stimmung: \(newEntry.mood) (\(newEntry.label))\n"
        input += "Gesagt: \"\(snippet)\"\n"
        input += "Themen: \(themes)\n"
        input += "Stimme: \(newEntry.dimensionsSummary)\n"
        if !newEntry.flags.isEmpty {
            input += "Auffaellig: \(newEntry.flags.prefix(3).joined(separator: ", "))\n"
        }
        if let contradiction = newEntry.contradiction, !contradiction.isEmpty {
            input += "Widerspruch: \(contradiction)\n"
        }
        return input
    }

    private func buildEmotionalInput(_ newEntry: MemoryEntryData) -> String {
        let name = UserDefaults.standard.string(forKey: "kluna_user_name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var input = ""
        if !name.isEmpty {
            input += "NAME DER PERSON: \(name)\n\n"
        }
        if !emotionalMap.isEmpty {
            input += "BISHERIGE EMOTIONALE KARTE:\n\(emotionalMap)\n\n"
        }
        input += "NEUER EINTRAG #\(newEntry.entryNumber):\n"
        input += "Themen: \(newEntry.themes.joined(separator: ", "))\n"
        input += "Stimme: \(newEntry.dimensionsSummary)\n"
        if let shift = newEntry.shift, !shift.isEmpty { input += "Stimmverlauf: \(shift)\n" }
        if let contradiction = newEntry.contradiction, !contradiction.isEmpty {
            input += "Widerspruch: \(contradiction)\n"
        }
        if let linguisticNote = newEntry.linguisticNote, !linguisticNote.isEmpty {
            input += "Sprachmuster: \(linguisticNote)\n"
        }
        return input
    }

    private func buildPredictionInput(_ newEntry: MemoryEntryData) -> String {
        let name = UserDefaults.standard.string(forKey: "kluna_user_name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var input = ""
        if !name.isEmpty {
            input += "NAME DER PERSON: \(name)\n\n"
        }
        input += "GESCHICHTE:\n\(episodes)\n\n"
        input += "EMOTIONALE KARTE:\n\(emotionalMap)\n\n"
        if !predictions.isEmpty { input += "BISHERIGE MUSTER:\n\(predictions)\n\n" }
        let dateStr = newEntry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        input += "NEUER EINTRAG #\(newEntry.entryNumber) (\(dateStr)):\n"
        input += "Stimmung: \(newEntry.mood). Stimme: \(newEntry.dimensionsSummary)\n"
        if !newEntry.flags.isEmpty { input += "Auffaellig: \(newEntry.flags.joined(separator: ", "))\n" }
        return input
    }

    private func buildIdentityInput(_ newEntry: MemoryEntryData) -> String {
        let name = UserDefaults.standard.string(forKey: "kluna_user_name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var input = ""
        if !name.isEmpty {
            input += "NAME DER PERSON: \(name)\n\n"
        }
        input += "GESCHICHTE:\n\(episodes)\n\n"
        input += "BEZIEHUNGEN:\n\(semantics)\n\n"
        input += "EMOTIONALE KARTE:\n\(emotionalMap)\n\n"
        input += "ERKANNTE MUSTER:\n\(predictions)\n\n"
        if !identity.isEmpty { input += "BISHERIGES PROFIL:\n\(identity)\n\n" }
        input += "Aktueller Eintrag #\(newEntry.entryNumber). Aktualisiere das Profil.\n"
        return input
    }

    private func parseMemoryText(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tagPrefixes = ["TEXT:", "MEMORY:", "GEDÄCHTNIS:", "GEDAECHTNIS:", "UPDATED MEMORY:"]
        for tag in tagPrefixes {
            if text.uppercased().hasPrefix(tag.uppercased()) {
                text = String(text.dropFirst(tag.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return sanitizeMemoryText(text)
    }

    private func appendFallbackEpisode(_ newEntry: MemoryEntryData) {
        let themeStr = newEntry.themes.prefix(3).joined(separator: ", ")
        let line = "Eintrag #\(newEntry.entryNumber): \(newEntry.mood). Themen: \(themeStr). \(newEntry.dimensionsSummary)"
        let combined = episodes.isEmpty ? line : "\(episodes)\n\(line)"
        episodes = sanitizeMemoryText(combined)
        UserDefaults.standard.set(episodes, forKey: episodesKey)
        print("🧠 ⚠️ Fallback episode append")
    }

    private func syncCurrentMemory() {
        currentMemory = fullMemory
        UserDefaults.standard.set(currentMemory, forKey: legacyMemoryKey)
        UserDefaults.standard.synchronize()
    }

    private func sanitizeMemoryText(_ text: String) -> String {
        var sanitized = stripMarkdown(text)
        if let klunaWord = try? NSRegularExpression(pattern: "\\b[Kk]luna\\b") {
            sanitized = klunaWord.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "du"
            )
        }
        sanitized = sanitized
            .replacingOccurrences(of: "Projektion", with: "")
            .replacingOccurrences(of: "Kontrollrituale", with: "")
            .replacingOccurrences(of: "Dysregulation", with: "")
            .replacingOccurrences(of: "Ambivalenz", with: "")
        return sanitized
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")

        let fullRange = NSRange(result.startIndex..., in: result)
        if let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*") {
            result = boldPattern.stringByReplacingMatches(in: result, range: fullRange, withTemplate: "$1")
        }
        if let italicPattern = try? NSRegularExpression(pattern: "\\*(.*?)\\*") {
            result = italicPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }

        result = result.replacingOccurrences(of: "\n- ", with: "\n")
        result = result.replacingOccurrences(of: "\n* ", with: "\n")

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

actor ClaudeCallThrottle {
    static let shared = ClaudeCallThrottle()
    private var lastCallTime: Date = .distantPast
    private var callCount: Int = 0

    func wait(minInterval: TimeInterval) async -> Int {
        callCount += 1
        let thisCall = callCount
        let elapsed = Date().timeIntervalSince(lastCallTime)
        if elapsed < minInterval {
            let waitTime = minInterval - elapsed
            print("🤖 [\(thisCall)] Throttle: waiting \(String(format: "%.1f", waitTime))s")
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        lastCallTime = Date()
        return thisCall
    }
}

enum PeriodicClaudeCalls {
    private static let voiceTypeKey = "kluna_last_voice_type_gen"
    private static let weeklyKey = "kluna_last_weekly_gen"
    private static let monthlyKey = "kluna_last_monthly_gen"

    static func shouldGenerateVoiceType() -> Bool {
        shouldGenerate(key: voiceTypeKey, interval: 7 * 86_400)
    }

    static func shouldGenerateWeeklySummary() -> Bool {
        shouldGenerate(key: weeklyKey, interval: 7 * 86_400)
    }

    static func shouldGenerateMonthlyLetter() -> Bool {
        shouldGenerate(key: monthlyKey, interval: 28 * 86_400)
    }

    static func markVoiceTypeGenerated() {
        markGenerated(key: voiceTypeKey)
    }

    static func markWeeklyGenerated() {
        markGenerated(key: weeklyKey)
    }

    static func markMonthlyGenerated() {
        markGenerated(key: monthlyKey)
    }

    private static func shouldGenerate(key: String, interval: TimeInterval) -> Bool {
        let last = UserDefaults.standard.double(forKey: key)
        return Date().timeIntervalSince1970 - last > interval
    }

    private static func markGenerated(key: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }
}

final class PromptHistory {
    static let shared = PromptHistory()

    private let storageKey = "kluna_prompt_history"
    private let maxHistory = 5

    var recentPrompts: [String] {
        get { UserDefaults.standard.stringArray(forKey: storageKey) ?? [] }
        set {
            let trimmed = Array(newValue.suffix(maxHistory))
            UserDefaults.standard.set(trimmed, forKey: storageKey)
            UserDefaults.standard.synchronize()
        }
    }

    func addPrompt(_ prompt: String) {
        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        var history = recentPrompts
        history.append(cleaned)
        recentPrompts = history
        print("💬 Prompt saved. History: \(recentPrompts.count) prompts")
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.synchronize()
    }
}

@MainActor
final class PromptManager: ObservableObject {
    static let shared = PromptManager()

    @Published var currentPrompt: String = "Wie geht es dir gerade?"

    private let userDefaultsKey = "kluna_current_prompt"
    private let timestampKey = "kluna_prompt_timestamp"

    private init() {
        loadSavedPrompt()
        if currentPrompt == "Wie geht es dir gerade?" && !hasAnyEntries() {
            currentPrompt = "Was bewegt dich gerade?"
        }
    }

    func loadSavedPrompt() {
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !saved.isEmpty {
            currentPrompt = saved
            return
        }

        // Migration from previous prompt keys.
        if let legacy = UserDefaults.standard.string(forKey: "kluna_personalized_prompt")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacy.isEmpty {
            currentPrompt = legacy
            UserDefaults.standard.set(legacy, forKey: userDefaultsKey)
            if UserDefaults.standard.double(forKey: timestampKey) == 0 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
            }
        }
    }

    func generateNextPrompt(recentEntries: [JournalEntry]) {
        let sorted = recentEntries.sorted(by: { $0.date > $1.date })
        guard let latest = sorted.first else { return }
        let snippet = latest.transcript
            .split(separator: ".")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let candidate: String
        if !snippet.isEmpty {
            let stem = String(snippet.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines)
            candidate = "Du hast eben \"\(stem)\" gesagt - was steckt für dich dahinter?"
        } else {
            candidate = "Was war heute der wichtigste Moment für deine Stimme?"
        }

        let prompt = sanitizePrompt(candidate)
        guard isValidPrompt(prompt) else { return }
        currentPrompt = prompt
        UserDefaults.standard.set(prompt, forKey: userDefaultsKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
        Task {
            await KlunaNotificationManager.shared.refreshPromptReminder()
        }
    }

    private func sanitizePrompt(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'"))
    }

    private func isValidPrompt(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("?"), trimmed.count < 100 else { return false }
        guard trimmed.split(separator: " ").count <= 15 else { return false }

        let lowered = trimmed.lowercased()
        let blocked = [
            "wie war dein tag",
            "was beschaeftigt dich",
            "was beschäftigt dich",
            "wie fuehlst du dich",
            "wie fühlst du dich",
        ]
        return !blocked.contains { lowered.contains($0) }
    }

    private func timeAgoString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        if minutes < 60 { return "Vor \(max(1, minutes)) Minuten" }
        if hours < 24 { return "Vor \(hours) Stunden" }
        let days = hours / 24
        return days == 1 ? "Gestern" : "Vor \(days) Tagen"
    }

    private func hasAnyEntries() -> Bool {
        let context = PersistenceController.shared.container.viewContext
        return !JournalManager(context: context).recentEntries(limit: 1).isEmpty
    }
}

@MainActor
final class QuestionGenerator: ObservableObject {
    static let shared = QuestionGenerator()

    @Published var currentQuestion: String = ""
    @Published var isGenerating: Bool = false

    private var generatedQuestions: [String] = []
    private var lastGenerationAt: Date?
    private let minimumGenerationInterval: TimeInterval = 2.0
    private var generationTask: Task<Void, Never>?

    private init() {}

    func loadSavedQuestion() {
        if let saved = UserDefaults.standard.string(forKey: "kluna_current_prompt"), !saved.isEmpty {
            currentQuestion = saved
            PromptManager.shared.currentPrompt = saved
            KlunaWidgetBridge.shared.updateQuestion(saved)
        }
    }

    func reset() {
        generationTask?.cancel()
        generationTask = nil
        generatedQuestions = []
        currentQuestion = ""
    }

    func generateNewQuestion() async {
        triggerGenerateNewQuestion()
    }

    private func triggerGenerateNewQuestion() {
        guard !isGenerating else { return }
        if let lastGenerationAt {
            let elapsed = Date().timeIntervalSince(lastGenerationAt)
            if elapsed < minimumGenerationInterval {
                print("💬 Question generation cooldown active (\(String(format: "%.2f", minimumGenerationInterval - elapsed))s)")
                return
            }
        }
        isGenerating = true
        lastGenerationAt = Date()

        let memory = KlunaMemory.shared.fullMemory
        let history = Array(generatedQuestions.suffix(5))
        let userName = UserDefaults.standard.string(forKey: "kluna_user_name") ?? ""

        var input = ""
        if !userName.isEmpty { input += "NAME: \(userName)\n\n" }
        if !memory.isEmpty { input += "GEDAECHTNIS:\n\(memory)\n\n" }
        if !history.isEmpty {
            input += "DIESE FRAGEN WURDEN SCHON GENERIERT (NICHT WIEDERHOLEN):\n"
            for q in history { input += "- \(q)\n" }
            input += "\nGeneriere eine KOMPLETT ANDERE Frage.\n\n"
        }
        input += "Tageszeit: \(timeOfDay(Date()))\n"

        generationTask?.cancel()
        generationTask = Task.detached(priority: .userInitiated) {
            defer {
                Task { @MainActor in
                    self.isGenerating = false
                    self.generationTask = nil
                }
            }

            do {
                let raw = try await CoachAPIManager.requestInsights(
                    payload: input,
                    systemPrompt: Self.questionGeneratorPrompt,
                    maxTokens: 120,
                    apiKey: Config.claudeAPIKey
                )
                let cleaned = await MainActor.run { self.normalizeQuestion(raw) }
                guard !cleaned.isEmpty, cleaned.hasSuffix("?") else {
                    print("💬 Question generation failed: invalid output")
                    return
                }

                await MainActor.run {
                    guard !self.generatedQuestions.contains(cleaned) else {
                        print("💬 Question generation skipped duplicate")
                        return
                    }
                    self.currentQuestion = cleaned
                    self.generatedQuestions.append(cleaned)
                    PromptManager.shared.currentPrompt = cleaned
                    PromptHistory.shared.addPrompt(cleaned)
                    UserDefaults.standard.set(cleaned, forKey: "kluna_current_prompt")
                    UserDefaults.standard.synchronize()
                    KlunaWidgetBridge.shared.updateQuestion(cleaned)
                    KlunaAnalytics.shared.track("question_refreshed")
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    print("💬 New question generated: \(cleaned)")
                }
            } catch is CancellationError {
                print("💬 Question generation cancelled")
            } catch let urlError as URLError where urlError.code == .cancelled {
                print("💬 Question generation cancelled (network)")
            } catch {
                print("💬 Question generation failed: \(error)")
            }
        }
    }

    private func normalizeQuestion(_ raw: String) -> String {
        var cleaned = stripMarkdown(raw)
        cleaned = cleaned
            .replacingOccurrences(of: "QUESTION:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "FRAGE:", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.contains("\n") {
            cleaned = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first(where: { !$0.isEmpty }) ?? cleaned
        }
        return cleaned
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")
        if let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*") {
            result = boldPattern.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }
        if let italicPattern = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.*?)(?<!\\*)\\*(?!\\*)") {
            result = italicPattern.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func timeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "morgens"
        case 12..<14: return "mittags"
        case 14..<18: return "nachmittags"
        case 18..<22: return "abends"
        default: return "nachts"
        }
    }

    private static let questionGeneratorPrompt = """
    Du generierst EINE Frage für ein Stimmtagebuch. Die Person wird die Frage sehen und darauf antworten, indem sie 20 Sekunden in ihr Handy spricht.

    Antworte NUR mit der Frage. Nichts anderes. Kein Format. Kein Tag. Nur die Frage.

    Die Frage MUSS:
    - Mit ? enden
    - Max 25 Worte
    - Persoenlich sein (nutze das Gedaechtnis wenn vorhanden)
    - Ueberraschend sein (nicht generisch)
    - Zum Nachdenken anregen
    - In einfacher Sprache sein

    Die Frage DARF NICHT:
    - Generisch sein ("Wie war dein Tag?", "Was beschaeftigt dich?")
    - Therapeutisch klingen ("Wie fuehlst du dich dabei?")
    - Sich wiederholen (siehe Liste der bereits gestellten Fragen)

    FRAGE-TYPEN (wechsle ab): Vertiefung, Abwesenheit, Muster, Ueberraschung, Zukunft, Dankbarkeit, Erinnerung, Identitaet, Beziehung, Koerper.
    Wenn kein Gedächtnis vorhanden: universelle aber trotzdem überraschende Frage.
    Wenn Gedaechtnis vorhanden: beziehe dich auf konkrete Namen, Themen, Muster.
    """
}

enum SupabaseManager {
    static let shared = SupabaseManagerImpl()
}

final class SupabaseManagerImpl {
    private var projectURL: String {
        Config.supabaseProjectURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    private var anonKey: String { Config.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var donorToken: String {
        if let token = UserDefaults.standard.string(forKey: "kluna_donor_token"), !token.isEmpty {
            return token
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: "kluna_donor_token")
        return token
    }

    func donateFullBiomarkers(
        features: [String: Double],
        dimensions: EngineVoiceDimensions,
        arousal: Float,
        acousticValence: Float,
        mood: String,
        flags: [AcousticFlag],
        deltas: BaselineDeltas?,
        pillarScores: PillarScores?,
        voiceDNA: VoiceDNAProfile?,
        segments: [DonationSegmentData],
        durationSeconds: Float,
        gainApplied: Float,
        entryCount: Int,
        hasBaseline: Bool
    ) async {
        let donationEnabled = UserDefaults.standard.bool(forKey: "kluna_data_donation_enabled")
            || UserDefaults.standard.bool(forKey: "kluna_donate_enabled")
        guard donationEnabled else { return }
        guard !projectURL.isEmpty, !anonKey.isEmpty else {
            print("DONATION FAILED: Supabase config missing")
            return
        }
        let ageGroup = UserDefaults.standard.string(forKey: "kluna_user_age_group") ?? "unknown"
        let gender = UserDefaults.standard.string(forKey: "kluna_user_gender") ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        var body: [String: Any] = [
            "age_group": ageGroup,
            "gender": gender,
            "mood": mood,
            "f0_mean": feature(features, keys: [FeatureKeys.f0Mean]),
            "f0_range_st": feature(features, keys: [FeatureKeys.f0RangeST, FeatureKeys.f0Range]),
            "f0_var": feature(features, keys: [FeatureKeys.f0Variability]),
            "f0_std_dev": feature(features, keys: [FeatureKeys.f0StdDev]),
            "jitter": feature(features, keys: [FeatureKeys.jitter]),
            "shimmer": feature(features, keys: [FeatureKeys.shimmer]),
            "hnr": feature(features, keys: [FeatureKeys.hnr]),
            "f1": feature(features, keys: [FeatureKeys.f1]),
            "f2": feature(features, keys: [FeatureKeys.f2]),
            "f3": feature(features, keys: [FeatureKeys.f3]),
            "f4": feature(features, keys: [FeatureKeys.f1Bandwidth]),
            "formant_dispersion": feature(features, keys: [FeatureKeys.formantDispersion]),
            "speech_rate": feature(features, keys: [FeatureKeys.speechRate]),
            "articulation_rate": feature(features, keys: [FeatureKeys.articulationRate]),
            "pause_rate": feature(features, keys: [FeatureKeys.pauseRate]),
            "pause_dur": feature(features, keys: [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration]),
            "loudness_rms": feature(features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness]),
            "loudness_rms_original": feature(features, keys: [FeatureKeys.loudnessRMSOriginal, FeatureKeys.loudnessRMS, FeatureKeys.loudness]),
            "loudness_std_dev": feature(features, keys: [FeatureKeys.loudnessStdDevOriginal, FeatureKeys.loudnessStdDev]),
            "loudness_dynamic_range": feature(features, keys: [FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange]),
            "spectral_body_ratio": feature(features, keys: ["spectralBodyRatio"]),
            "spectral_warmth_ratio": feature(features, keys: ["spectralWarmthRatio"]),
            "spectral_presence_ratio": feature(features, keys: ["spectralPresenceRatio"]),
            "spectral_air_ratio": feature(features, keys: ["spectralAirRatio"]),
            "arousal": arousal,
            "acoustic_valence": acousticValence,
            "dim_energy": dimensions.energy,
            "dim_tension": dimensions.tension,
            "dim_fatigue": dimensions.fatigue,
            "dim_warmth": dimensions.warmth,
            "dim_tempo": dimensions.tempo,
            "dim_expressiveness": dimensions.expressiveness,
            "flags": flags.map(\.rawValue),
            "duration_seconds": durationSeconds,
            "gain_applied": gainApplied,
            "entry_count_at_time": entryCount,
            "has_baseline": hasBaseline,
            "app_version": appVersion,
        ]
        let donationId = UUID().uuidString
        body["id"] = donationId

        do {
            if let pillarScores {
                body["pillar_voice_quality"] = pillarScores.voiceQuality
                body["pillar_clarity"] = pillarScores.clarity
                body["pillar_dynamics"] = pillarScores.dynamics
                body["pillar_rhythm"] = pillarScores.rhythm
                body["overall_score"] = pillarScores.overall
            }

            if let voiceDNA {
                body["dna_authority"] = voiceDNA.authority
                body["dna_charisma"] = voiceDNA.charisma
                body["dna_warmth"] = voiceDNA.warmth
                body["dna_composure"] = voiceDNA.composure
            }

            if let deltas {
                body["arousal_z_score"] = deltas.arousalZScore
                body["f0_z_score"] = deltas.f0ZScore
                body["jitter_z_score"] = deltas.jitterZScore
                body["hnr_z_score"] = deltas.hnrZScore
                body["speech_rate_z_score"] = deltas.speechRateZScore
                body["loudness_z_score"] = deltas.loudnessZScore
            }

            let inserted = try await insertDonation(body: body)
            if inserted, !segments.isEmpty {
                await insertSegments(donationId: donationId, segments: segments)
            }
        } catch {
            print("DONATION FAILED: \(error)")
        }
    }

    func donateConversation(_ convo: ConversationManager.ActiveConversation) async {
        let donationEnabled = UserDefaults.standard.bool(forKey: "kluna_data_donation_enabled")
            || UserDefaults.standard.bool(forKey: "kluna_donate_enabled")
        guard donationEnabled else {
            print("📊 conversation donation skipped: donation disabled (kluna_data_donation_enabled/kluna_donate_enabled)")
            return
        }
        guard !projectURL.isEmpty, !anonKey.isEmpty else {
            print("📊 conversation donation skipped: Supabase config missing")
            return
        }
        guard !convo.rounds.isEmpty else { return }
        guard let first = convo.rounds.first, let last = convo.rounds.last else { return }

        let ageGroup = UserDefaults.standard.string(forKey: "kluna_user_age_group")
            ?? UserDefaults.standard.string(forKey: "kluna_age_group")
            ?? ""
        let gender = UserDefaults.standard.string(forKey: "kluna_user_gender")
            ?? UserDefaults.standard.string(forKey: "kluna_gender")
            ?? ""
        let timeOfDay = donationTimeOfDay(convo.startedAt)
        let firstArousal = arousal(from: first.dimensions)
        let lastArousal = arousal(from: last.dimensions)
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        let conversationBody: [String: Any] = [
            "donor_token": donorToken,
            "age_group": ageGroup,
            "gender": gender,
            "time_of_day": timeOfDay,
            "round_count": convo.rounds.count,
            "duration_total_seconds": totalDuration(convo),
            "r1_energy": first.dimensions.energy,
            "r1_tension": first.dimensions.tension,
            "r1_fatigue": first.dimensions.fatigue,
            "r1_warmth": first.dimensions.warmth,
            "r1_expressiveness": first.dimensions.expressiveness,
            "r1_tempo": first.dimensions.tempo,
            "r1_arousal": firstArousal,
            "r1_mood": roundMood(first),
            "final_energy": last.dimensions.energy,
            "final_tension": last.dimensions.tension,
            "final_fatigue": last.dimensions.fatigue,
            "final_warmth": last.dimensions.warmth,
            "final_expressiveness": last.dimensions.expressiveness,
            "final_tempo": last.dimensions.tempo,
            "final_arousal": lastArousal,
            "final_mood": roundMood(last),
            "delta_energy": last.dimensions.energy - first.dimensions.energy,
            "delta_tension": last.dimensions.tension - first.dimensions.tension,
            "delta_fatigue": last.dimensions.fatigue - first.dimensions.fatigue,
            "delta_warmth": last.dimensions.warmth - first.dimensions.warmth,
            "delta_expressiveness": last.dimensions.expressiveness - first.dimensions.expressiveness,
            "delta_tempo": last.dimensions.tempo - first.dimensions.tempo,
            "delta_arousal": lastArousal - firstArousal,
            "emotional_direction": determineDirection(first: first.dimensions, last: last.dimensions),
            "had_breakthrough": detectBreakthrough(convo),
            "contradiction_count": convo.rounds.filter(\.hasContradiction).count,
            "app_version": appVersion,
            "entry_count_at_time": UserDefaults.standard.integer(forKey: "kluna_total_entries"),
        ]

        guard let conversationId = await insertReturningId(table: "conversations", body: conversationBody) else {
            print("📊 conversation insert failed")
            return
        }

        for (index, round) in convo.rounds.enumerated() {
            let prevQuestion = index > 0 ? convo.rounds[index - 1].claudeQuestion : nil
            var roundBody: [String: Any] = [
                "conversation_id": conversationId,
                "round_index": index,
                "donor_token": donorToken,
                "dim_energy": round.dimensions.energy,
                "dim_tension": round.dimensions.tension,
                "dim_fatigue": round.dimensions.fatigue,
                "dim_warmth": round.dimensions.warmth,
                "dim_expressiveness": round.dimensions.expressiveness,
                "dim_tempo": round.dimensions.tempo,
                "arousal": arousal(from: round.dimensions),
                "mood": roundMood(round),
                "flags": "",
                "duration_seconds": duration(of: round),
                "gain_applied": feature(round.features, keys: [FeatureKeys.gainFactor], fallback: 1),
                "hedging_score": round.linguistic.hedging,
                "distancing_score": round.linguistic.distancing,
            ]

            let featureMap: [(String, [String])] = [
                ("f0_mean", [FeatureKeys.f0Mean]),
                ("f0_range_st", [FeatureKeys.f0RangeST, FeatureKeys.f0Range]),
                ("f0_var", [FeatureKeys.f0Variability]),
                ("f0_std_dev", [FeatureKeys.f0StdDev]),
                ("jitter", [FeatureKeys.jitter]),
                ("shimmer", [FeatureKeys.shimmer]),
                ("hnr", [FeatureKeys.hnr]),
                ("f1", [FeatureKeys.f1]),
                ("f2", [FeatureKeys.f2]),
                ("f3", [FeatureKeys.f3]),
                ("f4", [FeatureKeys.f1Bandwidth]),
                ("formant_dispersion", [FeatureKeys.formantDispersion]),
                ("speech_rate", [FeatureKeys.speechRate]),
                ("articulation_rate", [FeatureKeys.articulationRate]),
                ("pause_rate", [FeatureKeys.pauseRate]),
                ("pause_dur", [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration]),
                ("loudness_rms", [FeatureKeys.loudnessRMS, FeatureKeys.loudness]),
                ("loudness_rms_original", [FeatureKeys.loudnessRMSOriginal, FeatureKeys.loudnessRMS, FeatureKeys.loudness]),
                ("loudness_std_dev", [FeatureKeys.loudnessStdDevOriginal, FeatureKeys.loudnessStdDev]),
                ("loudness_dynamic_range", [FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange]),
                ("spectral_body_ratio", ["spectralBodyRatio"]),
                ("spectral_warmth_ratio", ["spectralWarmthRatio"]),
                ("spectral_presence_ratio", ["spectralPresenceRatio"]),
                ("spectral_air_ratio", ["spectralAirRatio"]),
            ]
            for (sql, keys) in featureMap {
                roundBody[sql] = feature(round.features, keys: keys, fallback: 0)
            }

            if let delta = round.deltaFromPrevious {
                roundBody["delta_energy"] = delta.energy
                roundBody["delta_tension"] = delta.tension
                roundBody["delta_fatigue"] = delta.fatigue
                roundBody["delta_warmth"] = delta.warmth
                roundBody["delta_expressiveness"] = delta.expressiveness
                roundBody["delta_tempo"] = delta.tempo
            }

            if let question = prevQuestion, !question.isEmpty {
                roundBody["question_asked"] = question
                roundBody["question_type"] = classifyQuestion(question)
            }

            if !round.shifts.isEmpty {
                let shift = round.shifts.prefix(2).map { s in
                    "\(s.dimension)\(s.direction > 0 ? "↑" : "↓") bei \"\(s.triggerWords.joined(separator: " "))\""
                }.joined(separator: "; ")
                roundBody["shift_description"] = shift
            }

            _ = await insert(table: "conversation_rounds", body: roundBody)

            if index > 0, let question = prevQuestion, !question.isEmpty {
                let pre = convo.rounds[index - 1]
                let post = round
                let qeBody: [String: Any] = [
                    "donor_token": donorToken,
                    "conversation_id": conversationId,
                    "question_text": question,
                    "question_type": classifyQuestion(question),
                    "pre_energy": pre.dimensions.energy,
                    "pre_tension": pre.dimensions.tension,
                    "pre_fatigue": pre.dimensions.fatigue,
                    "pre_warmth": pre.dimensions.warmth,
                    "pre_expressiveness": pre.dimensions.expressiveness,
                    "pre_tempo": pre.dimensions.tempo,
                    "pre_arousal": arousal(from: pre.dimensions),
                    "pre_mood": roundMood(pre),
                    "post_energy": post.dimensions.energy,
                    "post_tension": post.dimensions.tension,
                    "post_fatigue": post.dimensions.fatigue,
                    "post_warmth": post.dimensions.warmth,
                    "post_expressiveness": post.dimensions.expressiveness,
                    "post_tempo": post.dimensions.tempo,
                    "post_arousal": arousal(from: post.dimensions),
                    "post_mood": roundMood(post),
                    "impact_tension": post.dimensions.tension - pre.dimensions.tension,
                    "impact_warmth": post.dimensions.warmth - pre.dimensions.warmth,
                    "impact_expressiveness": post.dimensions.expressiveness - pre.dimensions.expressiveness,
                    "opening_score": calculateOpeningScore(pre: pre.dimensions, post: post.dimensions),
                    "round_index": index,
                    "age_group": ageGroup,
                    "gender": gender,
                    "time_of_day": timeOfDay,
                ]
                _ = await insert(table: "question_effectiveness", body: qeBody)
            }
        }

        print("📊 ✅ Conversation donated: \(convo.rounds.count) rounds")
    }

    func donateCoachFeedback(entryId: UUID, feedback: Int, mood: String?, roundIndex: Int?) async {
        let donationEnabled = UserDefaults.standard.bool(forKey: "kluna_data_donation_enabled")
            || UserDefaults.standard.bool(forKey: "kluna_donate_enabled")
        guard donationEnabled else { return }
        guard !projectURL.isEmpty, !anonKey.isEmpty else { return }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let body: [String: Any] = [
            "donor_token": donorToken,
            "entry_id": entryId.uuidString,
            "feedback": feedback,
            "mood": mood ?? "",
            "round_index": roundIndex ?? 0,
            "app_version": appVersion
        ]

        _ = await insert(table: "coach_feedback", body: body)
    }

    private func insertDonation(body: [String: Any]) async throws -> Bool {
        guard let url = URL(string: "\(projectURL)/rest/v1/voice_donations") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applySupabaseAuthHeaders(to: &request)
        // Keep anonymous inserts private (no public read policy required).
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: sanitizeJSONObject(body))

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("DONATION STATUS: \(status)")
        if !(200...299).contains(status), let bodyText = String(data: data, encoding: .utf8), !bodyText.isEmpty {
            print("DONATION ERROR BODY: \(bodyText)")
        }
        return (200...299).contains(status)
    }

    private func insertSegments(donationId: String, segments: [DonationSegmentData]) async {
        guard let url = URL(string: "\(projectURL)/rest/v1/voice_segments") else { return }
        let segmentBodies: [[String: Any]] = segments.enumerated().map { index, seg in
            [
                "donation_id": donationId,
                "segment_index": index,
                "start_seconds": seg.startSeconds,
                "end_seconds": seg.endSeconds,
                "f0_mean": feature(seg.features, keys: [FeatureKeys.f0Mean]),
                "f0_range_st": feature(seg.features, keys: [FeatureKeys.f0RangeST, FeatureKeys.f0Range]),
                "jitter": feature(seg.features, keys: [FeatureKeys.jitter]),
                "shimmer": feature(seg.features, keys: [FeatureKeys.shimmer]),
                "hnr": feature(seg.features, keys: [FeatureKeys.hnr]),
                "speech_rate": feature(seg.features, keys: [FeatureKeys.speechRate]),
                "articulation_rate": feature(seg.features, keys: [FeatureKeys.articulationRate]),
                "pause_rate": feature(seg.features, keys: [FeatureKeys.pauseRate]),
                "pause_dur": feature(seg.features, keys: [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration]),
                "loudness_rms": feature(seg.features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness]),
                "loudness_dynamic_range": feature(seg.features, keys: [FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange]),
                "f1": feature(seg.features, keys: [FeatureKeys.f1]),
                "f2": feature(seg.features, keys: [FeatureKeys.f2]),
                "f3": feature(seg.features, keys: [FeatureKeys.f3]),
                "f4": feature(seg.features, keys: [FeatureKeys.f1Bandwidth]),
            ]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applySupabaseAuthHeaders(to: &request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: sanitizeJSONObjectArray(segmentBodies))

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("SEGMENTS STATUS: \(status)")
        } catch {
            print("SEGMENTS FAILED: \(error)")
        }
    }

    private func feature(_ features: [String: Double], keys: [String]) -> Double {
        for key in keys {
            if let value = features[key] { return value }
        }
        return 0
    }

    private func feature(_ features: [String: Float], keys: [String], fallback: Float) -> Float {
        for key in keys {
            if let value = features[key] { return value }
        }
        return fallback
    }

    private func insertReturningId(table: String, body: [String: Any]) async -> String? {
        guard let url = URL(string: "\(projectURL)/rest/v1/\(table)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applySupabaseAuthHeaders(to: &request)
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: sanitizeJSONObject(body))
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status) else {
                if let err = String(data: data, encoding: .utf8), !err.isEmpty {
                    print("📊 \(table) insert error: \(err)")
                }
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = json.first,
               let id = first["id"] as? String {
                return id
            }
        } catch {
            print("📊 \(table) insert failed: \(error)")
        }
        return nil
    }

    private func insert(table: String, body: [String: Any]) async -> Bool {
        guard let url = URL(string: "\(projectURL)/rest/v1/\(table)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applySupabaseAuthHeaders(to: &request)
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONSerialization.data(withJSONObject: sanitizeJSONObject(body))
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard (200...299).contains(status) else {
                if let err = String(data: data, encoding: .utf8), !err.isEmpty {
                    print("📊 \(table) insert error: \(err)")
                }
                return false
            }
            return true
        } catch {
            print("📊 \(table) insert failed: \(error)")
            return false
        }
    }

    private func arousal(from dims: EngineVoiceDimensions) -> Float {
        dims.energy * 0.4 + dims.expressiveness * 0.3 + dims.tempo * 0.3
    }

    private func roundMood(_ round: ConversationManager.ConversationRound) -> String {
        if let mood = round.claudeMood, !mood.isEmpty { return mood }
        let dims = round.dimensions
        if dims.tension > 0.65 { return "angespannt" }
        if dims.fatigue > 0.65 { return "erschoepft" }
        if dims.energy > 0.7 { return "aufgekratzt" }
        if dims.warmth > 0.6 { return "zufrieden" }
        return "ruhig"
    }

    private func determineDirection(first: EngineVoiceDimensions, last: EngineVoiceDimensions) -> String {
        let tensionDrop = first.tension - last.tension
        let warmthGain = last.warmth - first.warmth
        let expressGain = last.expressiveness - first.expressiveness
        if tensionDrop > 0.10 && warmthGain > 0.05 { return "opened_up" }
        if tensionDrop > 0.10 { return "calmed_down" }
        if tensionDrop < -0.10 { return "became_tense" }
        if expressGain > 0.10 { return "became_expressive" }
        return "stayed_stable"
    }

    private func detectBreakthrough(_ convo: ConversationManager.ActiveConversation) -> Bool {
        guard convo.rounds.count >= 2,
              let first = convo.rounds.first?.dimensions,
              let last = convo.rounds.last?.dimensions else { return false }
        let tensionDrop = first.tension - last.tension
        let warmthGain = last.warmth - first.warmth
        let expressGain = last.expressiveness - first.expressiveness
        return tensionDrop > 0.15 && (warmthGain > 0.05 || expressGain > 0.05)
    }

    private func calculateOpeningScore(pre: EngineVoiceDimensions, post: EngineVoiceDimensions) -> Float {
        let tensionRelief = pre.tension - post.tension
        let warmthGain = post.warmth - pre.warmth
        let expressGain = post.expressiveness - pre.expressiveness
        let fatigueRelief = pre.fatigue - post.fatigue
        return tensionRelief * 0.35 + warmthGain * 0.30 + expressGain * 0.25 + fatigueRelief * 0.10
    }

    private func classifyQuestion(_ question: String) -> String {
        let q = question.lowercased()
        if q.contains("dahinter") || q.contains("steckt") || q.contains("eigentlich") || q.contains("wirklich") {
            return "deepening"
        }
        if q.contains("nicht mehr") || q.contains("lange nicht") || q.contains("aufgehoert") || q.contains("vermisst") {
            return "absence"
        }
        if q.contains("aber") || q.contains("widerspruch") || q.contains("anders als") {
            return "contradiction"
        }
        if q.contains("immer") || q.contains("jedes mal") || q.contains("muster") || q.contains("oft") {
            return "pattern"
        }
        if q.contains("überrascht") || q.contains("ueberrascht") || q.contains("unerwartet") {
            return "surprise"
        }
        if q.contains("morgen") || q.contains("naechste") || q.contains("zukunft") {
            return "future"
        }
        return "open"
    }

    private func donationTimeOfDay(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "morgens"
        case 12..<14: return "mittags"
        case 14..<18: return "nachmittags"
        case 18..<22: return "abends"
        default: return "nachts"
        }
    }

    private func duration(of round: ConversationManager.ConversationRound) -> Float {
        guard let first = round.segments.first, let last = round.segments.last else { return 0 }
        return Float(max(0, last.endTime - first.startTime))
    }

    private func totalDuration(_ convo: ConversationManager.ActiveConversation) -> Float {
        let segmentDuration = convo.rounds.reduce(Float(0)) { partial, round in
            partial + duration(of: round)
        }
        if segmentDuration > 0 { return segmentDuration }
        return Float(max(0, Date().timeIntervalSince(convo.startedAt)))
    }

    private func applySupabaseAuthHeaders(to request: inout URLRequest) {
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        // publishable keys (sb_publishable_...) are not JWTs and must not be sent as Bearer token.
        if anonKey.split(separator: ".").count == 3 {
            request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        } else {
            print("📊 Supabase key is non-JWT (likely publishable). Sending apikey header only.")
        }
    }

    private func sanitizeJSONObject(_ obj: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        for (key, value) in obj {
            sanitized[key] = sanitizeJSONValue(value)
        }
        return sanitized
    }

    private func sanitizeJSONObjectArray(_ array: [[String: Any]]) -> [[String: Any]] {
        array.map { sanitizeJSONObject($0) }
    }

    private func sanitizeJSONValue(_ value: Any) -> Any {
        switch value {
        case let number as Double:
            return number.isFinite ? number : 0.0
        case let number as Float:
            return number.isFinite ? number : 0.0
        case let number as CGFloat:
            let d = Double(number)
            return d.isFinite ? d : 0.0
        case let dict as [String: Any]:
            return sanitizeJSONObject(dict)
        case let array as [[String: Any]]:
            return sanitizeJSONObjectArray(array)
        case let array as [Any]:
            return array.map { sanitizeJSONValue($0) }
        default:
            return value
        }
    }

    func fetchGlobalStats() async -> GlobalVoiceStats? {
        guard !projectURL.isEmpty, !anonKey.isEmpty else {
            print("GLOBAL STATS FAILED: Supabase config missing")
            return nil
        }
        guard let url = URL(string: "\(projectURL)/rest/v1/global_stats?select=*") else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        applySupabaseAuthHeaders(to: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(status) else {
                return nil
            }
            let decoded = try JSONDecoder().decode([SupabaseGlobalStatsResponse].self, from: data)
            guard let first = decoded.first else { return nil }
            return GlobalVoiceStats(
                totalDonors: first.total_donations,
                totalDataPoints: first.total_donations,
                avgWarmth: CGFloat(first.avg_warmth),
                avgStability: CGFloat(first.avg_stability),
                avgEnergy: CGFloat(first.avg_energy),
                avgTempo: CGFloat(first.avg_tempo),
                avgOpenness: CGFloat(first.avg_openness),
                mostCommonMood: first.most_common_mood
            )
        } catch {
            print("GLOBAL STATS ERROR: \(error)")
            return nil
        }
    }

    func fetchLiveCommunity() async -> LiveCommunityStats? {
        guard !projectURL.isEmpty, !anonKey.isEmpty else { return nil }
        guard let url = URL(string: "\(projectURL)/rest/v1/live_community?select=*") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        applySupabaseAuthHeaders(to: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode, (200...299).contains(status) else {
                return nil
            }
            let decoded = try JSONDecoder().decode([LiveCommunityStats].self, from: data)
            return decoded.first
        } catch {
            return nil
        }
    }
}

final class KlunaAnalytics {
    static let shared = KlunaAnalytics()

    private let tokenKey = "kluna_analytics_token"
    private let installDateKey = "kluna_install_date"
    private let lastCalibrationPhaseKey = "kluna_last_calibration_phase"

    private var projectURL: String {
        Config.supabaseProjectURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
    private var anonKey: String { Config.supabaseAnonKey.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private init() {}

    private var userToken: String {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            return token
        }
        let token = UUID().uuidString
        UserDefaults.standard.set(token, forKey: tokenKey)
        return token
    }

    func track(_ event: String, value: String? = nil) {
        guard !projectURL.isEmpty, !anonKey.isEmpty else {
            print("EVENT TRACK FAILED: Supabase config missing")
            return
        }
        let token = userToken
        let endpoint = "\(projectURL)/rest/v1/app_events"
        let key = anonKey
        let version = appVersion

        Task {
            guard let url = URL(string: endpoint) else { return }
            let body: [String: Any] = [
                "user_token": token,
                "event": event,
                "value": value ?? NSNull(),
                "app_version": version,
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 10
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "apikey")
            if key.split(separator: ".").count == 3 {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
        }
    }

    func trackAppOpened() {
        track("app_opened")
        track("day_active", value: "\(daysSinceInstall())")
    }

    func trackCalibrationPhase(_ phase: CalibrationPhase) {
        let value: String
        switch phase {
        case .initial: value = "initial"
        case .learning: value = "learning"
        case .stable: value = "stable"
        }
        let last = UserDefaults.standard.string(forKey: lastCalibrationPhaseKey)
        guard last != value else { return }
        UserDefaults.standard.set(value, forKey: lastCalibrationPhaseKey)
        track("calibration_phase", value: value)
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: installDateKey)
        UserDefaults.standard.removeObject(forKey: lastCalibrationPhaseKey)
    }

    private func daysSinceInstall() -> Int {
        let now = Date()
        let stored = UserDefaults.standard.object(forKey: installDateKey) as? Date
        let installDate: Date
        if let stored {
            installDate = stored
        } else {
            installDate = now
            UserDefaults.standard.set(now, forKey: installDateKey)
        }
        let start = Calendar.current.startOfDay(for: installDate)
        let today = Calendar.current.startOfDay(for: now)
        return max(0, Calendar.current.dateComponents([.day], from: start, to: today).day ?? 0)
    }
}

private struct SupabaseGlobalStatsResponse: Codable {
    let total_donations: Int
    let avg_warmth: Float
    let avg_stability: Float
    let avg_energy: Float
    let avg_tempo: Float
    let avg_openness: Float
    let most_common_mood: String
}

struct LiveCommunityStats: Codable {
    let active_today: Int?
    let dominant_mood_today: String?
    let conversations_today: Int?
    let avg_depth_today: Double?
}

struct DonationSegmentData {
    let startSeconds: Float
    let endSeconds: Float
    let features: [String: Double]
}
