import Foundation
import SwiftData

struct ImportService {
    /// Import questions from a JSON file bundled in the app resources.
    /// Questions are created with `isApproved = false`.
    /// Deduplicates by question text to prevent double-import.
    @MainActor
    static func importFromBundle(
        filename: String = "pending_review",
        extension ext: String = "json",
        autoApprove: Bool = false,
        into modelContext: ModelContext
    ) throws -> Int {
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            throw ImportError.fileNotFound(filename)
        }
        return try importFromURL(url, autoApprove: autoApprove, into: modelContext)
    }

    /// Import questions from a JSON file at an arbitrary URL.
    @MainActor
    static func importFromURL(_ url: URL, autoApprove: Bool = false, into modelContext: ModelContext) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([QuestionJSON].self, from: data)

        for (index, item) in decoded.enumerated() {
            try validate(item, at: index)
        }

        // Fetch existing question texts to deduplicate
        let descriptor = FetchDescriptor<Question>()
        let existing = try modelContext.fetch(descriptor)
        var existingTexts = Set(existing.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) })

        var importedCount = 0
        for item in decoded {
            let normalizedText = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !existingTexts.contains(normalizedText) else { continue }

            let question = Question(
                id: stableQuestionID(text: item.text, category: item.category),
                text: item.text,
                category: item.category,
                groundTruthValue: item.groundTruthValue,
                groundTruthUnit: item.groundTruthUnit,
                groundTruthDate: item.groundTruthDate ?? Date(),
                isEvergreen: item.isEvergreen,
                sourceURL: item.sourceURL,
                explanation: item.explanation,
                difficulty: item.estimatedDifficulty ?? item.difficulty ?? 0.5,
                isApproved: autoApprove
            )
            modelContext.insert(question)
            existingTexts.insert(normalizedText)
            importedCount += 1
        }

        try modelContext.save()
        return importedCount
    }

    /// Matches scripts/question_generator.py: UUID(int=FNV1a(text + category)).
    private static func stableQuestionID(text: String, category: String) -> UUID {
        let hash = StableHash.fnv1a(text + category)
        let hex = String(format: "%016llx", hash)
        let split = hex.index(hex.startIndex, offsetBy: 4)
        let uuidString = "00000000-0000-0000-\(hex[..<split])-\(hex[split...])"
        // The format above is constructed from exactly 16 hexadecimal digits.
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private static func validate(_ item: QuestionJSON, at index: Int) throws {
        let allowedCategories = Set(["geography", "science", "economics", "history", "popCulture", "currentEvents"])
        guard !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidQuestion(index: index, reason: "question text is empty")
        }
        guard !item.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidQuestion(index: index, reason: "explanation is empty")
        }
        guard !item.groundTruthUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.invalidQuestion(index: index, reason: "ground-truth unit is empty")
        }
        guard item.groundTruthValue.isFinite else {
            throw ImportError.invalidQuestion(index: index, reason: "ground-truth value is not finite")
        }
        guard allowedCategories.contains(item.category) else {
            throw ImportError.invalidQuestion(index: index, reason: "unsupported category \(item.category)")
        }
        guard let sourceURL = URL(string: item.sourceURL),
              sourceURL.scheme?.lowercased() == "https",
              sourceURL.host != nil else {
            throw ImportError.invalidQuestion(index: index, reason: "source URL must be an absolute HTTPS URL")
        }
        let difficulty = item.estimatedDifficulty ?? item.difficulty ?? 0.5
        guard difficulty.isFinite, (0...1).contains(difficulty) else {
            throw ImportError.invalidQuestion(index: index, reason: "difficulty must be between 0 and 1")
        }
    }
}

enum ImportError: LocalizedError {
    case fileNotFound(String)
    case invalidQuestion(index: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Could not find \(name) in app bundle."
        case .invalidQuestion(let index, let reason):
            return "Question \(index + 1) is invalid: \(reason)."
        }
    }
}

// JSON shape from question_generator.py output
private struct QuestionJSON: Decodable {
    let text: String
    let category: String
    let groundTruthValue: Double
    let groundTruthUnit: String
    let groundTruthDate: Date?
    let isEvergreen: Bool
    let sourceURL: String
    let explanation: String
    let estimatedDifficulty: Double?
    let difficulty: Double?

    enum CodingKeys: String, CodingKey {
        case text, category, groundTruthValue, groundTruthUnit, groundTruthDate
        case isEvergreen, sourceURL, explanation, estimatedDifficulty, difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        category = try container.decode(String.self, forKey: .category)
        groundTruthValue = try container.decode(Double.self, forKey: .groundTruthValue)
        groundTruthUnit = try container.decode(String.self, forKey: .groundTruthUnit)
        isEvergreen = try container.decode(Bool.self, forKey: .isEvergreen)
        sourceURL = try container.decode(String.self, forKey: .sourceURL)
        explanation = try container.decode(String.self, forKey: .explanation)
        estimatedDifficulty = try container.decodeIfPresent(Double.self, forKey: .estimatedDifficulty)
        difficulty = try container.decodeIfPresent(Double.self, forKey: .difficulty)

        // Parse date string "YYYY-MM-DD" if present
        if let dateString = try container.decodeIfPresent(String.self, forKey: .groundTruthDate) {
            guard let parsedDate = DateUtils.parseUTC(dateString: dateString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .groundTruthDate,
                    in: container,
                    debugDescription: "groundTruthDate must use YYYY-MM-DD"
                )
            }
            groundTruthDate = parsedDate
        } else {
            groundTruthDate = nil
        }
    }
}
