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

    /// Returns the DailySet for the given UTC date.
    /// If no set exists, creates one by randomly sampling approved questions.
    static func fetchDailySet(for utcDate: String, in modelContext: ModelContext) throws -> DailySet {
        // Check for existing set
        var descriptor = FetchDescriptor<DailySet>(
            predicate: #Predicate<DailySet> { $0.utcDate == utcDate }
        )
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor)
        if let set = existing.first {
            return set
        }

        // Build a new deterministic set using a date-seeded shuffle
        // Sort by id for stable order — SwiftData fetch order is non-deterministic
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

        // Seed a random generator from the date string so all users get the same set
        let seed = StableHash.fnv1a(utcDate)
        var rng = SeededRandomNumberGenerator(seed: seed)
        let selected = allApproved.shuffled(using: &rng).prefix(needed)
        let ids = selected.map(\.id)

        let dailySet = DailySet(utcDate: utcDate, questionIDs: ids)
        modelContext.insert(dailySet)
        try modelContext.save()
        return dailySet
    }

    /// Returns the Question objects for a given DailySet, preserving order.
    static func fetchQuestions(for dailySet: DailySet, in modelContext: ModelContext) throws -> [Question] {
        let ids = dailySet.questionIDs
        let allQuestions = try modelContext.fetch(FetchDescriptor<Question>())
        let questionMap = Dictionary(uniqueKeysWithValues: allQuestions.map { ($0.id, $0) })
        return ids.compactMap { questionMap[$0] }
    }
}

