import CloudKit
import Foundation

@MainActor
struct LeaderboardService {

    // MARK: - Public API

    /// Creates or updates the current user's leaderboard entry in the CloudKit public database.
    /// Handles server record conflicts with one retry. Fire-and-forget.
    static func upsertEntry(
        displayName: String,
        calibrationScore: Double,
        totalAnswered: Int,
        isPremium: Bool
    ) async {
        do {
            try await performUpsert(
                displayName: displayName,
                calibrationScore: calibrationScore,
                totalAnswered: totalAnswered,
                isPremium: isPremium,
                retrying: false
            )
        } catch {
            handleCKError(error, context: "[LeaderboardService] upsertEntry")
        }
    }

    /// Fetches the top 100 leaderboard entries sorted by calibration score descending.
    static func fetchLeaderboard() async throws -> [LeaderboardEntry] {
        let db = CKContainer(identifier: Constants.CloudKit.containerID).publicCloudDatabase

        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: Constants.CloudKit.leaderboardRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: Constants.CloudKitFields.LeaderboardEntry.calibrationScore,
                                                   ascending: false)]

        let (matchResults, _) = try await db.records(matching: query, resultsLimit: 100)

        return matchResults.compactMap { (_, result) -> LeaderboardEntry? in
            guard let record = try? result.get() else { return nil }
            return LeaderboardEntry.from(record: record)
        }
    }

    /// Fetches the current user's leaderboard entry, or nil if not found.
    static func fetchUserEntry() async -> LeaderboardEntry? {
        do {
            guard let userRecordName = try await fetchUserRecordName() else { return nil }
            let db = CKContainer(identifier: Constants.CloudKit.containerID).publicCloudDatabase
            let recordID = CKRecord.ID(recordName: "leaderboard-\(userRecordName)")
            let record = try await db.record(for: recordID)
            return LeaderboardEntry.from(record: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            handleCKError(error, context: "[LeaderboardService] fetchUserEntry")
            return nil
        }
    }

    // MARK: - Private helpers

    private static func performUpsert(
        displayName: String,
        calibrationScore: Double,
        totalAnswered: Int,
        isPremium: Bool,
        retrying: Bool
    ) async throws {
        guard let userRecordName = try await fetchUserRecordName() else {
            print("[LeaderboardService] upsertEntry: not authenticated, skipping")
            return
        }

        let db = CKContainer(identifier: Constants.CloudKit.containerID).publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "leaderboard-\(userRecordName)")

        // Try to fetch existing record to preserve server-assigned metadata
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: Constants.CloudKit.leaderboardRecordType, recordID: recordID)
        }

        let entry = LeaderboardEntry(
            id: userRecordName,
            displayName: displayName,
            calibrationScore: calibrationScore,
            totalAnswered: totalAnswered,
            lastUpdated: Date(),
            isPremium: isPremium
        )
        entry.populateRecord(record)

        do {
            _ = try await db.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged && !retrying {
            // One retry: server has a newer version — re-fetch and retry
            print("[LeaderboardService] upsertEntry: server record changed, retrying once")
            try await performUpsert(
                displayName: displayName,
                calibrationScore: calibrationScore,
                totalAnswered: totalAnswered,
                isPremium: isPremium,
                retrying: true
            )
        }
    }

    private static func fetchUserRecordName() async throws -> String? {
        do {
            let container = CKContainer(identifier: Constants.CloudKit.containerID)
            let userRecordID = try await container.userRecordID()
            return userRecordID.recordName
        } catch let error as CKError where error.code == .notAuthenticated {
            return nil
        }
    }

    private static func handleCKError(_ error: Error, context: String) {
        guard let ckError = error as? CKError else {
            print("\(context): unexpected error: \(error)")
            return
        }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            print("\(context): network unavailable, skipping")
        case .notAuthenticated:
            // Silent
            break
        case .quotaExceeded:
            print("\(context): WARNING — iCloud quota exceeded")
        default:
            print("\(context): CloudKit error \(ckError.code.rawValue): \(ckError.localizedDescription)")
        }
    }
}
