import Foundation
import SwiftData

@Model
final class Question {
    var id: UUID
    var text: String
    var category: String
    var groundTruthValue: Double
    var groundTruthUnit: String
    var groundTruthDate: Date
    var isEvergreen: Bool
    var sourceURL: String
    var explanation: String
    var difficulty: Double
    var isApproved: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        category: String,
        groundTruthValue: Double,
        groundTruthUnit: String,
        groundTruthDate: Date,
        isEvergreen: Bool,
        sourceURL: String,
        explanation: String,
        difficulty: Double = 0.5,
        isApproved: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.category = category
        self.groundTruthValue = groundTruthValue
        self.groundTruthUnit = groundTruthUnit
        self.groundTruthDate = groundTruthDate
        self.isEvergreen = isEvergreen
        self.sourceURL = sourceURL
        self.explanation = explanation
        self.difficulty = difficulty
        self.isApproved = isApproved
        self.createdAt = createdAt
    }
}
