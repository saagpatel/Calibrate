import SwiftUI
import SwiftData

struct ResultsView: View {
    let questions: [Question]
    let answers: [Answer]
    let scoreDelta: Double?

    @Query private var allAnswers: [Answer]
    @Query private var allQuestions: [Question]

    // MARK: - Career score computed from all data

    private var careerCalibrationResult: CalibrationResult {
        var truthMap: [UUID: Double] = [:]
        for q in allQuestions {
            truthMap[q.id] = q.groundTruthValue
        }
        let awts = allAnswers.compactMap { answer -> AnswerWithTruth? in
            guard let truth = truthMap[answer.questionID] else { return nil }
            return AnswerWithTruth(
                lower50: answer.lower50,
                upper50: answer.upper50,
                lower90: answer.lower90,
                upper90: answer.upper90,
                pointEstimate: answer.pointEstimate,
                truth: truth
            )
        }
        return CalibrationEngine.calibrationResult(answers: awts)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Header score summary
                scoreSummaryCard
                    .padding(.top, 8)

                // Per-question result cards
                ForEach(Array(zip(questions, answers).enumerated()), id: \.offset) { index, pair in
                    let (question, answer) = pair
                    QuestionResultCard(
                        index: index + 1,
                        question: question,
                        answer: answer
                    )
                }

                // Dashboard navigation
                NavigationLink(destination: CalibrationDashboardView()) {
                    HStack {
                        Text("See your dashboard")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Score Summary Card

    private var scoreSummaryCard: some View {
        VStack(spacing: 16) {
            Text("Today's Set Complete")
                .font(.headline)
                .foregroundStyle(.secondary)

            // Score delta
            if let delta = scoreDelta {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(delta >= 0 ? "+" : "")
                        .font(.largeTitle.bold())
                        .foregroundStyle(delta >= 0 ? .green : .red)
                    Text(String(format: "%.1f", delta))
                        .font(.largeTitle.bold())
                        .foregroundStyle(delta >= 0 ? .green : .red)
                    Text("pts")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("First score!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.blue)
            }

            Divider()

            // Career score
            switch careerCalibrationResult {
            case .insufficient:
                Text("Keep playing to unlock your calibration score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .result(let data):
                VStack(spacing: 4) {
                    Text("Career Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", data.score))
                        .font(.title.bold())
                    Text("\(data.sampleSize) questions answered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - QuestionResultCard

private struct QuestionResultCard: View {
    let index: Int
    let question: Question
    let answer: Answer

    private var truth: Double { question.groundTruthValue }
    private var unit: String { question.groundTruthUnit }

    private var hit50: Bool { answer.hit50(truth: truth) }
    private var hit90: Bool { answer.hit90(truth: truth) }
    private var mapePercent: Double { answer.mape(truth: truth) * 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Question header
            HStack(alignment: .top) {
                Text("Q\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(question.text)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    QuestionCategoryTag(category: question.category)
                }

                Spacer()
            }

            // Ground truth reveal
            VStack(alignment: .leading, spacing: 2) {
                Text("The answer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%g", truth))
                        .font(.title.bold())
                    Text(unit)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Interval results
            VStack(spacing: 10) {
                intervalResultRow(
                    label: "50% interval",
                    lower: answer.lower50,
                    upper: answer.upper50,
                    hit: hit50,
                    accentColor: Color.amber
                )

                intervalResultRow(
                    label: "90% interval",
                    lower: answer.lower90,
                    upper: answer.upper90,
                    hit: hit90,
                    accentColor: .blue
                )

                // Point estimate vs truth
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your estimate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%g", answer.pointEstimate))
                            .font(.subheadline.monospacedDigit())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Error")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", mapePercent))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(mapePercent <= 10 ? .green : mapePercent <= 30 ? .orange : .red)
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Explanation
            if !question.explanation.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(question.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Source link
            if !question.sourceURL.isEmpty, let url = URL(string: question.sourceURL) {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("Source")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func intervalResultRow(
        label: String,
        lower: Double,
        upper: Double,
        hit: Bool,
        accentColor: Color
    ) -> some View {
        HStack {
            Image(systemName: hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(hit ? accentColor : Color(.systemGray3))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("[\(formatNum(lower)), \(formatNum(upper))] \(unit)")
                    .font(.subheadline.monospacedDigit())
            }

            Spacer()

            Text(hit ? "Hit" : "Miss")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(hit ? accentColor : Color(.systemGray))
        }
        .padding(10)
        .background(
            (hit ? accentColor : Color(.systemGray3)).opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatNum(_ value: Double) -> String {
        String(format: "%g", value)
    }
}
