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

        // Fetch existing question texts to deduplicate
        let descriptor = FetchDescriptor<Question>()
        let existing = try modelContext.fetch(descriptor)
        let existingTexts = Set(existing.map(\.text))

        var importedCount = 0
        for item in decoded {
            guard !existingTexts.contains(item.text) else { continue }

            let question = Question(
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
            importedCount += 1
        }

        try modelContext.save()
        return importedCount
    }
}

enum ImportError: LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Could not find \(name) in app bundle."
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
            groundTruthDate = DateUtils.parseUTC(dateString: dateString)
        } else {
            groundTruthDate = nil
        }
    }
}
