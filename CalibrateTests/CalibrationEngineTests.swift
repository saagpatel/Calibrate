import XCTest
@testable import Calibrate

final class CalibrationEngineTests: XCTestCase {

    // MARK: - Factory Helpers

    /// Create an AnswerWithTruth with explicit control over interval bounds.
    private func makeAnswer(
        lower50: Double = 0, upper50: Double = 0,
        lower90: Double = 0, upper90: Double = 0,
        pointEstimate: Double = 0, truth: Double = 100
    ) -> AnswerWithTruth {
        AnswerWithTruth(
            lower50: lower50, upper50: upper50,
            lower90: lower90, upper90: upper90,
            pointEstimate: pointEstimate, truth: truth
        )
    }

    /// Create a set where exactly 50% of 50-intervals hit and 90% of 90-intervals hit.
    /// Requires count to be >= 10 and divisible by 10 for exact percentages.
    private func makePerfectCalibrationSet(count: Int) -> [AnswerWithTruth] {
        let hit50Count = count / 2      // 50% hit
        let hit90Count = count * 9 / 10 // 90% hit
        return (0..<count).map { i in
            let hits50 = i < hit50Count
            let hits90 = i < hit90Count
            return makeAnswer(
                lower50: hits50 ? 50 : 200,
                upper50: hits50 ? 150 : 300,
                lower90: hits90 ? 50 : 200,
                upper90: hits90 ? 150 : 300,
                pointEstimate: 100,
                truth: 100
            )
        }
    }

    /// Create a set where NO intervals hit (all miss).
    private func makeAllMissSet(count: Int) -> [AnswerWithTruth] {
        (0..<count).map { _ in
            makeAnswer(
                lower50: 200, upper50: 300,
                lower90: 200, upper90: 300,
                pointEstimate: 250, truth: 100
            )
        }
    }

    /// Create a set where ALL intervals hit (100% hit rate both levels).
    private func makeAllHitSet(count: Int) -> [AnswerWithTruth] {
        (0..<count).map { _ in
            makeAnswer(
                lower50: 50, upper50: 150,
                lower90: 50, upper90: 150,
                pointEstimate: 100, truth: 100
            )
        }
    }

    // MARK: - Test 1: Perfect calibration → score = 100

    func testPerfectCalibration() {
        let answers = makePerfectCalibrationSet(count: 100)
        let result = CalibrationEngine.calibrationResult(answers: answers)

        guard case .result(let data) = result else {
            XCTFail("Expected .result, got .insufficient")
            return
        }

        XCTAssertEqual(data.score, 100.0, accuracy: 0.01)
        XCTAssertEqual(data.hit50Rate, 0.50, accuracy: 0.01)
        XCTAssertEqual(data.hit90Rate, 0.90, accuracy: 0.01)
        XCTAssertEqual(data.overallError, 0.0, accuracy: 0.01)
    }

    // MARK: - Test 2: All overconfident (0% hit rate) → score = 0

    func testAllOverconfident() {
        let answers = makeAllMissSet(count: 10)
        let result = CalibrationEngine.calibrationResult(answers: answers)

        guard case .result(let data) = result else {
            XCTFail("Expected .result, got .insufficient")
            return
        }

        // error50 = |0.50 - 0.0| = 0.50
        // error90 = |0.90 - 0.0| = 0.90
        // overallError = (0.50 + 0.90) / 2 = 0.70
        // score = 100 - (0.70 / 0.50 * 100) = 100 - 140 = -40, clamped to 0
        XCTAssertEqual(data.score, 0.0, accuracy: 0.01)
        XCTAssertEqual(data.hit50Rate, 0.0, accuracy: 0.01)
        XCTAssertEqual(data.hit90Rate, 0.0, accuracy: 0.01)
    }

    // MARK: - Test 3: All underconfident (100% hit rate) → score = 40

    func testAllUnderconfident() {
        let answers = makeAllHitSet(count: 10)
        let result = CalibrationEngine.calibrationResult(answers: answers)

        guard case .result(let data) = result else {
            XCTFail("Expected .result, got .insufficient")
            return
        }

        // error50 = |0.50 - 1.0| = 0.50
        // error90 = |0.90 - 1.0| = 0.10
        // overallError = (0.50 + 0.10) / 2 = 0.30
        // score = 100 - (0.30 / 0.50 * 100) = 100 - 60 = 40
        XCTAssertEqual(data.score, 40.0, accuracy: 0.01)
        XCTAssertEqual(data.hit50Rate, 1.0, accuracy: 0.01)
        XCTAssertEqual(data.hit90Rate, 1.0, accuracy: 0.01)
        XCTAssertEqual(data.overallError, 0.30, accuracy: 0.01)
    }

    // MARK: - Test 4: Perfect 50%, all miss 90% → score = 10

    func testPerfect50AllMiss90() {
        // 10 answers: 5 hit 50%, 0 hit 90%
        let answers = (0..<10).map { i in
            let hits50 = i < 5
            return makeAnswer(
                lower50: hits50 ? 50 : 200,
                upper50: hits50 ? 150 : 300,
                lower90: 200,  // all miss 90%
                upper90: 300,
                pointEstimate: 100,
                truth: 100
            )
        }

        let result = CalibrationEngine.calibrationResult(answers: answers)

        guard case .result(let data) = result else {
            XCTFail("Expected .result, got .insufficient")
            return
        }

        // error50 = |0.50 - 0.50| = 0.0
        // error90 = |0.90 - 0.0| = 0.90
        // overallError = (0.0 + 0.90) / 2 = 0.45
        // score = 100 - (0.45 / 0.50 * 100) = 100 - 90 = 10
        XCTAssertEqual(data.score, 10.0, accuracy: 0.01)
        XCTAssertEqual(data.hit50Rate, 0.50, accuracy: 0.01)
        XCTAssertEqual(data.hit90Rate, 0.0, accuracy: 0.01)
    }

    // MARK: - Test 5: window=30 with 50 answers uses only last 30

    func testWindowUsesLastN() {
        // First 20: all miss (to skew if included)
        let bad = makeAllMissSet(count: 20)
        // Last 30: perfect calibration
        let good = makePerfectCalibrationSet(count: 30)
        let allAnswers = bad + good

        XCTAssertEqual(allAnswers.count, 50)

        let result = CalibrationEngine.calibrationResult(answers: allAnswers, window: 30)

        guard case .result(let data) = result else {
            XCTFail("Expected .result, got .insufficient")
            return
        }

        // Should only see the last 30 (perfect calibration)
        XCTAssertEqual(data.sampleSize, 30)
        XCTAssertEqual(data.score, 100.0, accuracy: 0.01)
    }

    // MARK: - Test 6: window=5 with 3 answers returns .insufficient

    func testWindowInsufficientSample() {
        let answers = [
            makeAnswer(pointEstimate: 100, truth: 100),
            makeAnswer(pointEstimate: 100, truth: 100),
            makeAnswer(pointEstimate: 100, truth: 100),
        ]

        let result = CalibrationEngine.calibrationResult(answers: answers, window: 5)

        guard case .insufficient = result else {
            XCTFail("Expected .insufficient for 3 answers with window=5")
            return
        }
    }

    // MARK: - Test 7: Empty input returns .insufficient

    func testEmptyInputReturnsInsufficient() {
        let result = CalibrationEngine.calibrationResult(answers: [])

        guard case .insufficient = result else {
            XCTFail("Expected .insufficient for empty input")
            return
        }
    }

    // MARK: - Test 8: knowledgeScore with perfect point estimates returns 100

    func testKnowledgeScorePerfect() {
        let answers = (0..<10).map { _ in
            makeAnswer(pointEstimate: 100, truth: 100)
        }

        let score = CalibrationEngine.knowledgeScore(answers: answers)
        XCTAssertEqual(score, 100.0, accuracy: 0.01)
    }

    // MARK: - Additional: knowledgeScore edge cases

    func testKnowledgeScoreEmpty() {
        let score = CalibrationEngine.knowledgeScore(answers: [])
        XCTAssertEqual(score, 0.0)
    }

    func testKnowledgeScoreWithZeroTruth() {
        let answers = [makeAnswer(pointEstimate: 50, truth: 0)]
        let score = CalibrationEngine.knowledgeScore(answers: answers)
        // All truths are 0 → filtered out → returns 0
        XCTAssertEqual(score, 0.0)
    }

    // MARK: - reliabilityPoints

    func testReliabilityPointsInsufficientSample() {
        let answers = [makeAnswer(), makeAnswer()]
        let points = CalibrationEngine.reliabilityPoints(answers: answers)
        XCTAssertTrue(points.isEmpty)
    }

    func testReliabilityPointsPerfectCalibration() {
        let answers = makePerfectCalibrationSet(count: 100)
        let points = CalibrationEngine.reliabilityPoints(answers: answers)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].stated, 0.50)
        XCTAssertEqual(points[0].observed, 0.50, accuracy: 0.01)
        XCTAssertEqual(points[1].stated, 0.90)
        XCTAssertEqual(points[1].observed, 0.90, accuracy: 0.01)
    }

    // MARK: - P1: knowledgeScore with non-trivial MAPE

    func testKnowledgeScoreNonTrivialMAPE() {
        // pointEstimate=150, truth=100 → MAPE = |150-100|/100 = 0.50
        // score = 100 - (0.50 * 100) = 50
        let answers = [makeAnswer(pointEstimate: 150, truth: 100)]
        let score = CalibrationEngine.knowledgeScore(answers: answers)
        XCTAssertEqual(score, 50.0, accuracy: 0.01)
    }

    // MARK: - P1: calibrationResult at exactly minimumSampleSize (5)

    func testCalibrationAtExactMinimumSampleSize() {
        let answers = makePerfectCalibrationSet(count: 10).prefix(5).map { $0 }
        let result = CalibrationEngine.calibrationResult(answers: answers)

        guard case .result(let data) = result else {
            XCTFail("Expected .result for exactly 5 answers, got .insufficient")
            return
        }
        XCTAssertEqual(data.sampleSize, 5)
    }

    // MARK: - P2: window larger than array uses all answers

    func testWindowLargerThanArrayUsesAllAnswers() {
        // 4 answers with window=100 → 4 < minimumSampleSize → .insufficient
        let answers = [
            makeAnswer(pointEstimate: 100, truth: 100),
            makeAnswer(pointEstimate: 100, truth: 100),
            makeAnswer(pointEstimate: 100, truth: 100),
            makeAnswer(pointEstimate: 100, truth: 100),
        ]
        let result = CalibrationEngine.calibrationResult(answers: answers, window: 100)
        guard case .insufficient = result else {
            XCTFail("Expected .insufficient for 4 answers with window=100")
            return
        }
    }
}
