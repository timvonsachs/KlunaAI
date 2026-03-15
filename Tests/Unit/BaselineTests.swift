import XCTest
@testable import KlunaAI

final class BaselineTests: XCTestCase {
    func testBaselineEngineInit() {
        let engine = BaselineEngine()
        XCTAssertNotNil(engine)
    }

    func testPopulationFallbackDiffersByVoiceType() {
        let deep = PopulationBaseline.values(for: .deep)
        let high = PopulationBaseline.values(for: .high)
        XCTAssertNotEqual(deep[FeatureKeys.f0Mean]?.mean, high[FeatureKeys.f0Mean]?.mean)
    }
}
