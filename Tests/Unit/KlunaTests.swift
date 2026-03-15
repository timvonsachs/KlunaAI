import XCTest
@testable import KlunaAI

final class KlunaCoreSanityTests: XCTestCase {
    func testDimensionWeightsComplete() {
        for dimension in PerformanceDimension.allCases {
            XCTAssertNotNil(Config.dimensionWeights[dimension], "\(dimension) missing weight")
        }
    }

    func testEWMAAlpha() {
        XCTAssertGreaterThan(Config.ewmaAlpha, 0)
        XCTAssertLessThan(Config.ewmaAlpha, 1)
    }

    func testScoreScaleFactorIsPositive() {
        XCTAssertGreaterThan(Config.scoreScaleFactor, 0)
    }
}
