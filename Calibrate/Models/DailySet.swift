import Foundation
import SwiftData

@Model
final class DailySet {
    var id: UUID
    var utcDate: String
    var questionIDs: [UUID]
    var publishedAt: Date

    init(
        id: UUID = UUID(),
        utcDate: String,
        questionIDs: [UUID],
        publishedAt: Date = Date()
    ) {
        self.id = id
        self.utcDate = utcDate
        self.questionIDs = questionIDs
        self.publishedAt = publishedAt
    }
}
