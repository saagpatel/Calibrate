import CloudKit
import Foundation
import SwiftData

enum QuestionServiceError: LocalizedError {
    case noApprovedQuestions
    case dailySetNotFound(String)
    case insufficientQuestions(needed: Int, found: Int)

    var errorDescription: String? {
        switch self {
        case .noApprovedQuestions:
            return "No approved questions available."
        case .dailySetNotFound(let date):
            return "No daily set found for \(date)."
        case .insufficientQuestions(let needed, let found):
            return "Daily set needs \(needed) questions but only \(found) are available."
        }
    }
}

@MainActor
struct QuestionService {

    // MARK: - Public API

    /// Returns the DailySet for the given UTC date using a 3-layer strategy:
    /// 1. SwiftData cache (if fresh within ttlDays)
    /// 2. CloudKit public DB
    /// 3. Stale cache or local deterministic generation
    static func fetchDailySet(for utcDate: String, in modelContext: ModelContext) async throws -> DailySet {
        // Layer 1: Fresh SwiftData cache
        if let cached = try fetchCachedDailySet(for: utcDate, in: modelContext) {
            let age = DateUtils.daysBetween(
                from: DateUtils.formatUTC(date: cached.publishedAt),
                to: DateUtils.currentUTCDate()
            )
            if age < Constants.Cache.ttlDays {
                return cached
            }
            // Cache exists but is stale — try CK before falling back to it
            if let ckSet = try? await fetchDailySetFromCK(utcDate: utcDate, in: modelContext) {
                return ckSet
            }
            // Layer 3a: Use stale cache rather than fail
            return cached
        }

        // Layer 2: CloudKit public DB
        if let ckSet = try? await fetchDailySetFromCK(utcDate: utcDate, in: modelContext) {
            return ckSet
        }

        // Layer 3b: Local deterministic generation
        return try generateLocalDailySet(for: utcDate, in: modelContext)
    }

    /// Returns the Question objects for a given DailySet, preserving order.
    static func fetchQuestions(for dailySet: DailySet, in modelContext: ModelContext) throws -> [Question] {
        let ids = dailySet.questionIDs
        let allQuestions = try modelContext.fetch(FetchDescriptor<Question>())
        let questionMap = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.id, $0) })
        return ids.compactMap { questionMap[$0] }
    }

    // MARK: - Private: SwiftData cache

    private static func fetchCachedDailySet(for utcDate: String, in modelContext: ModelContext) throws -> DailySet? {
        var descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate<DailySet> { $0.utcDate == utcDate }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Private: CloudKit fetch

    private static func fetchDailySetFromCK(utcDate: String, in modelContext: ModelContext) async throws -> DailySet {
        let db = CKContainer(identifier: Constants.CloudKit.containerID).publicCloudDatabase

        let predicate = NSPredicate(format: "%K == %@",
                                    Constants.CloudKitFields.DailySet.utcDate, utcDate)
        let query = CKQuery(recordType: Constants.CloudKit.dailySetRecordType, predicate: predicate)

        let (matchResults, _) = try await db.records(matching: query, resultsLimit: 1)
        guard let (_, result) = matchResults.first,
              let record = try? result.get() else {
            throw QuestionServiceError.dailySetNotFound(utcDate)
        }

        let fields = Constants.CloudKitFields.DailySet.self
        guard
            let questionIDStrings = record[fields.questionIDs] as? [String],
            let publishedAt = record[fields.publishedAt] as? Date
        else {
            throw QuestionServiceError.dailySetNotFound(utcDate)
        }

        let questionIDs = questionIDStrings.compactMap { UUID(uuidString: $0) }
        guard !questionIDs.isEmpty else {
            throw QuestionServiceError.dailySetNotFound(utcDate)
        }

        // Fetch question records from CK to populate local cache
        let fetchedQuestions = try await fetchQuestionsFromCK(ids: questionIDs, db: db)
        let existingQuestions = try modelContext.fetch(FetchDescriptor<Question>())
        let existingIDs = Set(existingQuestions.map(\.id))
        for question in fetchedQuestions {
            if !existingIDs.contains(question.id) {
                modelContext.insert(question)
            }
        }

        let dailySet = DailySet(utcDate: utcDate, questionIDs: questionIDs, publishedAt: publishedAt)
        modelContext.insert(dailySet)
        try modelContext.save()
        return dailySet
    }

    private static func fetchQuestionsFromCK(ids: [UUID], db: CKDatabase) async throws -> [Question] {
        guard !ids.isEmpty else { return [] }

        let idStrings = ids.map { $0.uuidString }
        let predicate = NSPredicate(format: "%K IN %@",
                                    Constants.CloudKitFields.Question.questionID, idStrings)
        let query = CKQuery(recordType: Constants.CloudKit.questionRecordType, predicate: predicate)

        let (matchResults, _) = try await db.records(matching: query, resultsLimit: ids.count)

        var questions: [Question] = []
        for (_, result) in matchResults {
            guard let record = try? result.get(),
                  let question = questionFromCKRecord(record) else { continue }
            questions.append(question)
        }
        return questions
    }

    private static func questionFromCKRecord(_ record: CKRecord) -> Question? {
        let fields = Constants.CloudKitFields.Question.self
        guard
            let idString = record[fields.questionID] as? String,
            let uuid = UUID(uuidString: idString),
            let text = record[fields.text] as? String,
            let category = record[fields.category] as? String,
            let groundTruthValue = record[fields.groundTruthValue] as? Double,
            let groundTruthUnit = record[fields.groundTruthUnit] as? String,
            let groundTruthDate = record[fields.groundTruthDate] as? Date,
            let isEvergreen = record[fields.isEvergreen] as? Int64,
            let explanation = record[fields.explanation] as? String,
            let difficulty = record[fields.difficulty] as? Double,
            let isApproved = record[fields.isApproved] as? Int64
        else {
            return nil
        }

        let sourceURL = record[fields.sourceURL] as? String ?? ""

        return Question(
            id: uuid,
            text: text,
            category: category,
            groundTruthValue: groundTruthValue,
            groundTruthUnit: groundTruthUnit,
            groundTruthDate: groundTruthDate,
            isEvergreen: isEvergreen != 0,
            sourceURL: sourceURL,
            explanation: explanation,
            difficulty: difficulty,
            isApproved: isApproved != 0
        )
    }

    // MARK: - Private: Local deterministic generation

    private static func generateLocalDailySet(for utcDate: String, in modelContext: ModelContext) throws -> DailySet {
        let allApproved = try modelContext.fetch(
            FetchDescriptor<Question>(
                predicate: #Predicate<Question> { $0.isApproved == true },
                sortBy: [SortDescriptor(\Question.id)]
            )
        )
        guard !allApproved.isEmpty else { throw QuestionServiceError.noApprovedQuestions }

        let needed = Constants.Calibration.questionsPerDay
        guard allApproved.count >= needed else {
            throw QuestionServiceError.insufficientQuestions(needed: needed, found: allApproved.count)
        }

        let seed = StableHash.fnv1a(utcDate)
        var rng = SeededRandomNumberGenerator(seed: seed)
        let selected = allApproved.shuffled(using: &rng).prefix(needed)
        let ids = selected.map(\.id)

        let dailySet = DailySet(utcDate: utcDate, questionIDs: ids)
        modelContext.insert(dailySet)
        try modelContext.save()
        return dailySet
    }
}
