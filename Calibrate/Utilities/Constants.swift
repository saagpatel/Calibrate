import Foundation

enum Constants {
    enum CloudKit {
        static let containerID = "iCloud.com.calibrate.app"
        static let questionRecordType = "Question"
        static let dailySetRecordType = "DailySet"
        static let leaderboardRecordType = "LeaderboardEntry"
        static let friendGroupRecordType = "FriendGroup"
    }

    enum StoreKit {
        static let monthlyProductID = "com.calibrate.premium.monthly"
        static let annualProductID = "com.calibrate.premium.annual"
    }

    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAdminMode = "isAdminMode"
        static let hasSeededQuestions = "hasSeededQuestions"
    }

    enum Notifications {
        static let dailyCategoryID = "DAILY_CALIBRATION"
        static let dailyHour = 8
        static let dailyMinute = 0
    }

    enum Calibration {
        static let recentWindowSize = 30
        static let minimumSampleSize = 5
        static let questionsPerDay = 5
    }

    enum Tutorial {
        static let questionText = "How many bones are in the adult human body?"
        static let groundTruthValue = 206.0
        static let groundTruthUnit = "bones"
        static let category = "science"
        static let explanation = "Adults have 206 bones — babies are born with about 270, but many fuse together as they grow."
    }

    enum Cache {
        static let ttlDays = 7
    }

    enum CloudKitFields {
        enum Question {
            static let questionID = "questionID"
            static let text = "text"
            static let category = "category"
            static let groundTruthValue = "groundTruthValue"
            static let groundTruthUnit = "groundTruthUnit"
            static let groundTruthDate = "groundTruthDate"
            static let isEvergreen = "isEvergreen"
            static let sourceURL = "sourceURL"
            static let explanation = "explanation"
            static let difficulty = "difficulty"
            static let isApproved = "isApproved"
        }

        enum DailySet {
            static let utcDate = "utcDate"
            static let questionIDs = "questionIDs"
            static let publishedAt = "publishedAt"
        }

        enum LeaderboardEntry {
            static let userRecordName = "userRecordName"
            static let displayName = "displayName"
            static let calibrationScore = "calibrationScore"
            static let totalAnswered = "totalAnswered"
            static let lastUpdated = "lastUpdated"
            static let isPremium = "isPremium"
        }

        enum Answer {
            static let questionID = "questionID"
            static let utcDate = "utcDate"
            static let pointEstimate = "pointEstimate"
            static let lower50 = "lower50"
            static let upper50 = "upper50"
            static let lower90 = "lower90"
            static let upper90 = "upper90"
            static let submittedAt = "submittedAt"
        }

        enum UserProfile {
            static let displayName = "displayName"
            static let currentStreak = "currentStreak"
            static let longestStreak = "longestStreak"
            static let totalQuestionsAnswered = "totalQuestionsAnswered"
            static let calibrationScore = "calibrationScore"
            static let lastCompletedUTCDate = "lastCompletedUTCDate"
        }
    }
}
