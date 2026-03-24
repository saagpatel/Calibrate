import Foundation
import SwiftData

@Model
final class Answer {
    var id: UUID
    var questionID: UUID
    var utcDate: String
    var pointEstimate: Double
    var lower50: Double
    var upper50: Double
    var lower90: Double
    var upper90: Double
    var submittedAt: Date

    func hit50(truth: Double) -> Bool {
        lower50 <= truth && truth <= upper50
    }

    func hit90(truth: Double) -> Bool {
        lower90 <= truth && truth <= upper90
    }

    func mape(truth: Double) -> Double {
        guard truth != 0 else { return 0 }
        return abs(pointEstimate - truth) / abs(truth)
    }

    init(
        id: UUID = UUID(),
        questionID: UUID,
        utcDate: String,
        pointEstimate: Double,
        lower50: Double,
        upper50: Double,
        lower90: Double,
        upper90: Double,
        submittedAt: Date = Date()
    ) {
        self.id = id
        self.questionID = questionID
        self.utcDate = utcDate
        self.pointEstimate = pointEstimate
        self.lower50 = lower50
        self.upper50 = upper50
        self.lower90 = lower90
        self.upper90 = upper90
        self.submittedAt = submittedAt
    }
}
