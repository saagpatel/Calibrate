import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var joinedAt: Date
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedUTCDate: String
    var totalQuestionsAnswered: Int
    var isPremiumCached: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        joinedAt: Date = Date(),
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastCompletedUTCDate: String = "",
        totalQuestionsAnswered: Int = 0,
        isPremiumCached: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = joinedAt
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedUTCDate = lastCompletedUTCDate
        self.totalQuestionsAnswered = totalQuestionsAnswered
        self.isPremiumCached = isPremiumCached
    }
}
