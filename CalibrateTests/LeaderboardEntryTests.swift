import CloudKit
import XCTest
@testable import Calibrate

final class LeaderboardEntryTests: XCTestCase {

    // MARK: - Helpers

    private func makeRecord(recordName: String = "leaderboard-abc123") -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        return CKRecord(recordType: Constants.CloudKit.leaderboardRecordType, recordID: recordID)
    }

    // MARK: - Test 1: from(record:) maps all fields correctly

    func testFromRecordMapsAllFields() {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        let record = makeRecord(recordName: "leaderboard-user42")
        record[fields.displayName] = "Alice"
        record[fields.calibrationScore] = 87.5
        record[fields.totalAnswered] = Int64(120)
        let now = Date()
        record[fields.lastUpdated] = now
        record[fields.isPremium] = Int64(1)

        let entry = LeaderboardEntry.from(record: record)

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.id, "leaderboard-user42")
        XCTAssertEqual(entry?.displayName, "Alice")
        XCTAssertEqual(entry?.calibrationScore ?? 0, 87.5, accuracy: 0.001)
        XCTAssertEqual(entry?.totalAnswered, 120)
        XCTAssertEqual(entry?.lastUpdated, now)
        XCTAssertEqual(entry?.isPremium, true)
    }

    // MARK: - Test 2: from(record:) returns nil when displayName is missing

    func testFromRecordReturnsNilWhenDisplayNameMissing() {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        let record = makeRecord()
        // displayName intentionally omitted
        record[fields.calibrationScore] = 75.0
        record[fields.totalAnswered] = Int64(50)
        record[fields.lastUpdated] = Date()
        record[fields.isPremium] = Int64(0)

        let entry = LeaderboardEntry.from(record: record)

        XCTAssertNil(entry, "from(record:) must return nil when displayName is missing")
    }

    // MARK: - Test 3: from(record:) returns nil when calibrationScore is missing

    func testFromRecordReturnsNilWhenCalibrationScoreMissing() {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        let record = makeRecord()
        record[fields.displayName] = "Bob"
        // calibrationScore intentionally omitted
        record[fields.totalAnswered] = Int64(30)
        record[fields.lastUpdated] = Date()
        record[fields.isPremium] = Int64(0)

        let entry = LeaderboardEntry.from(record: record)

        XCTAssertNil(entry, "from(record:) must return nil when calibrationScore is missing")
    }

    // MARK: - Test 4: isPremium is false when isPremium field is zero

    func testIsPremiumFalseWhenFieldIsZero() {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        let record = makeRecord()
        record[fields.displayName] = "Charlie"
        record[fields.calibrationScore] = 60.0
        record[fields.totalAnswered] = Int64(10)
        record[fields.lastUpdated] = Date()
        record[fields.isPremium] = Int64(0)

        let entry = LeaderboardEntry.from(record: record)

        XCTAssertNotNil(entry)
        XCTAssertFalse(entry?.isPremium ?? true, "isPremium must be false when field value is 0")
    }

    // MARK: - Test 5: Entries sort descending by calibrationScore

    func testEntriesSortDescendingByCalibrationScore() {
        let entries = [
            LeaderboardEntry(id: "a", displayName: "A", calibrationScore: 55.0, totalAnswered: 10, lastUpdated: Date(), isPremium: false),
            LeaderboardEntry(id: "b", displayName: "B", calibrationScore: 90.0, totalAnswered: 20, lastUpdated: Date(), isPremium: true),
            LeaderboardEntry(id: "c", displayName: "C", calibrationScore: 72.5, totalAnswered: 15, lastUpdated: Date(), isPremium: false)
        ]

        let sorted = entries.sorted { $0.calibrationScore > $1.calibrationScore }

        XCTAssertEqual(sorted[0].id, "b", "Highest score should be first")
        XCTAssertEqual(sorted[1].id, "c", "Second highest should be second")
        XCTAssertEqual(sorted[2].id, "a", "Lowest score should be last")
    }

    // MARK: - Test 6: populateRecord round-trip preserves all fields

    func testPopulateRecordRoundTrip() {
        let fields = Constants.CloudKitFields.LeaderboardEntry.self
        let now = Date()
        let original = LeaderboardEntry(
            id: "user-xyz",
            displayName: "Diana",
            calibrationScore: 83.3,
            totalAnswered: 200,
            lastUpdated: now,
            isPremium: true
        )

        let record = makeRecord(recordName: "leaderboard-user-xyz")
        original.populateRecord(record)

        XCTAssertEqual(record[fields.displayName] as? String, "Diana")
        XCTAssertEqual((record[fields.calibrationScore] as? Double) ?? 0, 83.3, accuracy: 0.001)
        XCTAssertEqual(record[fields.totalAnswered] as? Int64, Int64(200))
        XCTAssertEqual(record[fields.lastUpdated] as? Date, now)
        XCTAssertEqual(record[fields.isPremium] as? Int64, Int64(1))
        XCTAssertEqual(record[fields.userRecordName] as? String, "user-xyz")

        // Verify from(record:) reconstructs the entry faithfully
        let reconstructed = LeaderboardEntry.from(record: record)
        XCTAssertNotNil(reconstructed)
        XCTAssertEqual(reconstructed?.displayName, original.displayName)
        XCTAssertEqual(reconstructed?.calibrationScore ?? 0, original.calibrationScore, accuracy: 0.001)
        XCTAssertEqual(reconstructed?.totalAnswered, original.totalAnswered)
        XCTAssertEqual(reconstructed?.isPremium, original.isPremium)
    }
}
