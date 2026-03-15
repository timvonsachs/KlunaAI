import XCTest
@testable import KlunaAI

final class ClaudeParserTests: XCTestCase {
    func testParsesCompleteResponse() {
        let text = """
        MOOD: begeistert
        LABEL: Voller Energie
        TEXT: Deine Stimme strahlt richtig Kraft aus. Die App scheint dich wirklich zu begeistern.
        INSIGHT: Energetischer als die ganze Woche
        THEMES: App, Entwicklung, Motivation
        PROMPT: Was genau an der App hat dich heute so begeistert?
        CONTRADICTION: Ich bin müde | Deine Stimme klingt hellwach
        """

        let result = CoachAPIManager.parseResponse(text)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.mood, "begeistert")
        XCTAssertEqual(result?.label, "Voller Energie")
        XCTAssertTrue(result?.coachText.contains("Kraft") ?? false)
        XCTAssertEqual(result?.insight, "Energetischer als die ganze Woche")
        XCTAssertEqual(result?.themes.count, 3)
        XCTAssertTrue(result?.prompt?.hasSuffix("?") ?? false)
        XCTAssertEqual(result?.contradiction?.wordsSay, "Ich bin müde")
        XCTAssertEqual(result?.contradiction?.voiceSays, "Deine Stimme klingt hellwach")
    }

    func testParsesMinimalResponse() {
        let text = """
        MOOD: ruhig
        LABEL: Entspannt
        TEXT: Deine Stimme klingt gelassen.
        THEMES: Abend
        """
        let result = CoachAPIManager.parseResponse(text)
        XCTAssertEqual(result?.mood, "ruhig")
        XCTAssertEqual(result?.label, "Entspannt")
        XCTAssertNotNil(result?.coachText)
        XCTAssertNil(result?.contradiction)
        XCTAssertNil(result?.prompt)
    }

    func testGarbageInputReturnsNilForFallbackPath() {
        let result = CoachAPIManager.parseResponse("Kein gueltiges Format")
        XCTAssertNil(result)
    }

    func testPromptMustEndWithQuestionMark() {
        let text = """
        MOOD: ruhig
        LABEL: OK
        TEXT: Test.
        PROMPT: Erzaehl mir mehr
        """
        let result = CoachAPIManager.parseResponse(text)
        XCTAssertNil(result?.prompt)
    }

    func testContradictionWithoutPipeIsIgnored() {
        let text = """
        MOOD: ruhig
        LABEL: Neutral
        TEXT: Kurzer Satz.
        CONTRADICTION: Kein Pipe hier
        """
        let result = CoachAPIManager.parseResponse(text)
        XCTAssertNil(result?.contradiction)
    }
}
