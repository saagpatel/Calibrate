import Foundation

struct AnswerWithTruth: Sendable {
    let lower50: Double
    let upper50: Double
    let lower90: Double
    let upper90: Double
    let pointEstimate: Double
    let truth: Double

    func hit50() -> Bool { lower50 <= truth && truth <= upper50 }
    func hit90() -> Bool { lower90 <= truth && truth <= upper90 }
    func mape() -> Double {
        guard truth != 0 else { return 0 }
        return abs(pointEstimate - truth) / abs(truth)
    }
}

enum CalibrationResult: Sendable {
    case insufficient
    case result(CalibrationData)
}

struct CalibrationData: Sendable {
    let score: Double
    let hit50Rate: Double
    let hit90Rate: Double
    let error50: Double
    let error90: Double
    let overallError: Double
    let sampleSize: Int
}

struct CalibrationEngine {

    /// Compute calibration score for a set of answers.
    /// Score: 0–100, higher = better calibrated.
    /// Maximum possible overallError = 0.50 (all intervals miss at both confidence levels).
    static func calibrationResult(answers: [AnswerWithTruth], window: Int? = nil) -> CalibrationResult {
        let sample = window.map { Array(answers.suffix($0)) } ?? answers
        guard sample.count >= Constants.Calibration.minimumSampleSize else { return .insufficient }

        let hit50Count = Double(sample.filter { $0.hit50() }.count)
        let hit90Count = Double(sample.filter { $0.hit90() }.count)
        let total = Double(sample.count)

        let hit50Rate = hit50Count / total
        let hit90Rate = hit90Count / total

        let error50 = abs(0.50 - hit50Rate)
        let error90 = abs(0.90 - hit90Rate)
        let overallError = (error50 + error90) / 2.0

        let score = max(0.0, min(100.0, 100.0 - (overallError / 0.50 * 100.0)))

        return .result(CalibrationData(
            score: score,
            hit50Rate: hit50Rate,
            hit90Rate: hit90Rate,
            error50: error50,
            error90: error90,
            overallError: overallError,
            sampleSize: sample.count
        ))
    }

    /// Mean absolute percentage error of point estimates.
    /// Returns 0–100 score (100 = perfect point estimates).
    static func knowledgeScore(answers: [AnswerWithTruth]) -> Double {
        guard !answers.isEmpty else { return 0 }
        let validAnswers = answers.filter { $0.truth != 0 }
        guard !validAnswers.isEmpty else { return 0 }
        let mape = validAnswers.map { $0.mape() }.reduce(0, +) / Double(validAnswers.count)
        return max(0.0, min(100.0, 100.0 - (mape * 100.0)))
    }

    /// Reliability diagram data points: [(statedConfidence, observedFrequency)]
    /// For Swift Charts calibration curve.
    static func reliabilityPoints(answers: [AnswerWithTruth]) -> [(stated: Double, observed: Double)] {
        guard answers.count >= Constants.Calibration.minimumSampleSize else { return [] }
        let total = Double(answers.count)
        let hit50Rate = Double(answers.filter { $0.hit50() }.count) / total
        let hit90Rate = Double(answers.filter { $0.hit90() }.count) / total
        return [(0.50, hit50Rate), (0.90, hit90Rate)]
    }
}
