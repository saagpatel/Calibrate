import XCTest
import SwiftData
@testable import Calibrate

@MainActor
final class QuestionServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([Question.self, DailySet.self, Answer.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: config)
        context = container.mainContext
        try insertApprovedQuestions(count: 20)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func insertApprovedQuestions(count: Int) throws {
        for i in 0..<count {
            let question = Question(
                text: "Question \(i)?",
                category: "science",
                groundTruthValue: Double(i),
                groundTruthUnit: "units",
                groundTruthDate: Date(),
                isEvergreen: true,
                sourceURL: "https://en.wikipedia.org/wiki/Science",
                explanation: "Explanation for question \(i).",
                difficulty: 0.5,
                isApproved: true
            )
            context.insert(question)
        }
        try context.save()
    }

    private func countDailySets() throws -> Int {
        let descriptor = FetchDescriptor<DailySet>()
        return try context.fetch(descriptor).count
    }

    // MARK: - Test 1: Same date always returns the same question IDs

    func testSameDateReturnsSameQuestionIDs() async throws {
        let date = "2026-03-22"
        let set1 = try await QuestionService.fetchDailySet(for: date, in: context)
        let set2 = try await QuestionService.fetchDailySet(for: date, in: context)
        let set3 = try await QuestionService.fetchDailySet(for: date, in: context)

        XCTAssertEqual(set1.questionIDs, set2.questionIDs, "Same date must return identical question IDs on second call.")
        XCTAssertEqual(set1.questionIDs, set3.questionIDs, "Same date must return identical question IDs on third call.")
    }

    // MARK: - Test 2: Different dates return different question IDs

    func testDifferentDatesReturnDifferentQuestionIDs() async throws {
        let set1 = try await QuestionService.fetchDailySet(for: "2026-03-22", in: context)
        let set2 = try await QuestionService.fetchDailySet(for: "2026-03-23", in: context)

        XCTAssertNotEqual(set1.questionIDs, set2.questionIDs, "Different dates should produce different question selections.")
    }

    // MARK: - Test 3: Returns exactly 5 question IDs

    func testReturnsExactlyFiveQuestionIDs() async throws {
        let dailySet = try await QuestionService.fetchDailySet(for: "2026-03-22", in: context)
        XCTAssertEqual(dailySet.questionIDs.count, Constants.Calibration.questionsPerDay,
                       "DailySet must contain exactly \(Constants.Calibration.questionsPerDay) question IDs.")
    }

    // MARK: - Test 4: All returned IDs exist in the approved questions pool

    func testAllReturnedIDsExistInApprovedQuestions() async throws {
        let dailySet = try await QuestionService.fetchDailySet(for: "2026-03-22", in: context)

        let approvedDescriptor = FetchDescriptor<Question>(
            predicate: #Predicate<Question> { $0.isApproved == true }
        )
        let approved = try context.fetch(approvedDescriptor)
        let approvedIDs = Set(approved.map(\.id))

        for id in dailySet.questionIDs {
            XCTAssertTrue(approvedIDs.contains(id), "Question ID \(id) must exist in the approved questions pool.")
        }
    }

    // MARK: - Test 5: Throws when fewer than 5 approved questions exist

    func testThrowsWhenInsufficientApprovedQuestions() async throws {
        // Delete all questions to force the error path.
        let allDescriptor = FetchDescriptor<Question>()
        let allQuestions = try context.fetch(allDescriptor)
        for q in allQuestions { context.delete(q) }
        try context.save()

        do {
            _ = try await QuestionService.fetchDailySet(for: "2026-03-22", in: context)
            XCTFail("Expected error to be thrown")
        } catch let error as QuestionServiceError {
            switch error {
            case .insufficientQuestions, .noApprovedQuestions:
                break // Correct error type
            default:
                XCTFail("Unexpected QuestionServiceError case: \(error)")
            }
        }
    }

    // MARK: - Test 6: Second call for same date does not create a new DailySet record

    func testCachesResultAndDoesNotDuplicateDailySet() async throws {
        let date = "2026-03-22"
        _ = try await QuestionService.fetchDailySet(for: date, in: context)
        _ = try await QuestionService.fetchDailySet(for: date, in: context)

        let count = try countDailySets()
        XCTAssertEqual(count, 1, "Calling fetchDailySet twice for the same date must create exactly one DailySet record.")
    }

    // MARK: - Test 7: fetchQuestions returns correct questions in order

    func testFetchQuestionsReturnsCorrectOrderedQuestions() async throws {
        let dailySet = try await QuestionService.fetchDailySet(for: "2026-03-22", in: context)
        let questions = try QuestionService.fetchQuestions(for: dailySet, in: context)

        XCTAssertEqual(questions.count, Constants.Calibration.questionsPerDay)
        XCTAssertEqual(questions.map(\.id), dailySet.questionIDs, "Questions must be returned in the same order as DailySet.questionIDs.")
    }

    // MARK: - Test 8: fetchQuestions drops missing IDs silently

    func testFetchQuestionsDropsMissingIDs() async throws {
        let fakeSet = DailySet(utcDate: "2026-01-01", questionIDs: [UUID(), UUID()])
        context.insert(fakeSet)
        try context.save()

        let questions = try QuestionService.fetchQuestions(for: fakeSet, in: context)
        XCTAssertEqual(questions.count, 0, "Non-existent IDs should be silently dropped.")
    }
}
