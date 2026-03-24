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
}
