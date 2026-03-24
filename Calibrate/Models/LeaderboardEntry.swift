import CloudKit
import Foundation

struct LeaderboardEntry: Sendable, Identifiable {
    let id: String
    let displayName: String
    let calibrationScore: Double
    let totalAnswered: Int
    let lastUpdated: Date
    let isPremium: Bool

    static func from(record: CKRecord) -> LeaderboardEntry? {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        guard
            let displayName = record[fields.displayName] as? String,
            let calibrationScore = record[fields.calibrationScore] as? Double,
            let totalAnsweredRaw = record[fields.totalAnswered] as? Int64,
            let lastUpdated = record[fields.lastUpdated] as? Date,
            let isPremiumRaw = record[fields.isPremium] as? Int64
        else {
            return nil
        }
        return LeaderboardEntry(
            id: record.recordID.recordName,
            displayName: displayName,
            calibrationScore: calibrationScore,
            totalAnswered: Int(totalAnsweredRaw),
            lastUpdated: lastUpdated,
            isPremium: isPremiumRaw != 0
        )
    }

    func populateRecord(_ record: CKRecord) {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        record[fields.userRecordName] = id
        record[fields.displayName] = displayName
        record[fields.calibrationScore] = calibrationScore
        record[fields.totalAnswered] = Int64(totalAnswered)
        record[fields.lastUpdated] = lastUpdated
        record[fields.isPremium] = isPremium ? Int64(1) : Int64(0)
    }
}
