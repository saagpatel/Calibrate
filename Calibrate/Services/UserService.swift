import CloudKit
import Foundation

@MainActor
struct UserService {

    // MARK: - Public API

    /// Batch-writes answers for a given date to the CloudKit private database.
    /// Fire-and-forget: logs errors, never throws.
    static func syncAnswersToCK(answers: [Answer], utcDate: String) async {
        guard !answers.isEmpty else { return }

        let db = CKContainer(identifier: Constants.CloudKit.containerID).privateCloudDatabase
        let fields = Constants.CloudKitFields.Answer.self

        var records: [CKRecord] = []
        for answer in answers {
            let recordID = CKRecord.ID(recordName: "answer-\(answer.id.uuidString)")
            let record = CKRecord(recordType: "Answer", recordID: recordID)
            record[fields.questionID] = answer.questionID.uuidString
            record[fields.utcDate] = answer.utcDate
            record[fields.pointEstimate] = answer.pointEstimate
            record[fields.lower50] = answer.lower50
            record[fields.upper50] = answer.upper50
            record[fields.lower90] = answer.lower90
            record[fields.upper90] = answer.upper90
            record[fields.submittedAt] = answer.submittedAt
            records.append(record)
        }

        do {
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = .changedKeys
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                db.add(operation)
            }
        } catch {
            handleCKError(error, context: "[UserService] syncAnswersToCK for date \(utcDate)")
        }
    }

    /// Saves the user's profile and calibration score to the CloudKit private database.
    /// Fire-and-forget: logs errors, never throws.
    static func syncProfileToCK(profile: UserProfile, calibrationScore: Double) async {
        let db = CKContainer(identifier: Constants.CloudKit.containerID).privateCloudDatabase
        let fields = Constants.CloudKitFields.UserProfile.self

        let recordID = CKRecord.ID(recordName: "userprofile-\(profile.id.uuidString)")
        let record = CKRecord(recordType: "UserProfile", recordID: recordID)
        record[fields.displayName] = profile.displayName
        record[fields.currentStreak] = Int64(profile.currentStreak)
        record[fields.longestStreak] = Int64(profile.longestStreak)
        record[fields.totalQuestionsAnswered] = Int64(profile.totalQuestionsAnswered)
        record[fields.calibrationScore] = calibrationScore
        record[fields.lastCompletedUTCDate] = profile.lastCompletedUTCDate

        do {
            _ = try await db.save(record)
        } catch {
            handleCKError(error, context: "[UserService] syncProfileToCK for profile \(profile.id.uuidString)")
        }
    }

    // MARK: - Private helpers

    private static func handleCKError(_ error: Error, context: String) {
        guard let ckError = error as? CKError else {
            print("\(context): unexpected error: \(error)")
            return
        }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            print("\(context): network unavailable, skipping sync")
        case .notAuthenticated:
            // Silent — user hasn't signed in to iCloud
            break
        case .quotaExceeded:
            print("\(context): WARNING — iCloud quota exceeded")
        default:
            print("\(context): CloudKit error \(ckError.code.rawValue): \(ckError.localizedDescription)")
        }
    }
}
