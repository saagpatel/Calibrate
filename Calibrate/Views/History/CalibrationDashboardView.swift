import SwiftUI
import SwiftData

struct CalibrationDashboardView: View {
    @Query private var answers: [Answer]
    @Query private var questions: [Question]
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    // Build AnswerWithTruth by joining Answer on Question by questionID
    private var answersWithTruth: [AnswerWithTruth] {
        let questionMap = Dictionary(questions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return answers.compactMap { answer -> AnswerWithTruth? in
            guard let question = questionMap[answer.questionID] else { return nil }
            return AnswerWithTruth(
                lower50: answer.lower50,
                upper50: answer.upper50,
                lower90: answer.lower90,
                upper90: answer.upper90,
                pointEstimate: answer.pointEstimate,
                truth: question.groundTruthValue
            )
        }
    }

    private var careerCalibration: CalibrationResult {
        CalibrationEngine.calibrationResult(answers: answersWithTruth)
    }

    private var recentCalibration: CalibrationResult {
        CalibrationEngine.calibrationResult(
            answers: answersWithTruth,
            window: Constants.Calibration.recentWindowSize
        )
    }

    private var knowledgeScore: Double {
        CalibrationEngine.knowledgeScore(answers: answersWithTruth)
    }

    private var isTodayComplete: Bool {
        guard let profile else { return false }
        return DateUtils.isToday(utcDate: profile.lastCompletedUTCDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                scoreCardsSection
                hitRatesSection
                streakSection
                ctaSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .navigationTitle("Calibrate")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 8) {
            Text("Calibration Score")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            switch careerCalibration {
            case .insufficient:
                insufficientHero
            case .result(let data):
                sufficientHero(data: data)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var insufficientHero: some View {
        VStack(spacing: 16) {
            Text("—")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)

            let answered = answersWithTruth.count
            let needed = Constants.Calibration.minimumSampleSize
            let remaining = max(0, needed - answered)

            VStack(spacing: 8) {
                Text("Play \(remaining) more question\(remaining == 1 ? "" : "s") to unlock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemFill))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor)
                            .frame(
                                width: geo.size.width * (Double(answered) / Double(needed)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 20)

                Text("\(answered) / \(needed) answers")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func sufficientHero(data: CalibrationData) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", data.score))
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(calibrationColor(score: data.score))

            Text("out of 100")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Text("All-time · \(data.sampleSize) questions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: - Score Cards

    private var scoreCardsSection: some View {
        HStack(spacing: 12) {
            scoreCard(
                title: "Recent",
                subtitle: "Last 30",
                calibration: recentCalibration
            )
            knowledgeCard
        }
    }

    private func scoreCard(title: String, subtitle: String, calibration: CalibrationResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            switch calibration {
            case .insufficient:
                Text("—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Not enough data")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            case .result(let data):
                Text(String(format: "%.0f", data.score))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(calibrationColor(score: data.score))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var knowledgeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Knowledge")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if answersWithTruth.isEmpty {
                Text("—")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("No answers yet")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text(String(format: "%.0f", knowledgeScore))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(calibrationColor(score: knowledgeScore))
                Text("Point accuracy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Hit Rates Section

    private var hitRatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Interval Accuracy")
                .font(.headline)
                .fontWeight(.bold)

            switch careerCalibration {
            case .insufficient:
                Text("Answer \(Constants.Calibration.minimumSampleSize) questions to see interval accuracy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .result(let data):
                VStack(spacing: 12) {
                    hitRateRow(
                        label: "50% Intervals",
                        rate: data.hit50Rate,
                        ideal: 0.50,
                        description: "Ideal: 50% — half your 50% intervals should contain the answer"
                    )
                    Divider()
                    hitRateRow(
                        label: "90% Intervals",
                        rate: data.hit90Rate,
                        ideal: 0.90,
                        description: "Ideal: 90% — most of your 90% intervals should contain the answer"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func hitRateRow(label: String, rate: Double, ideal: Double, description: String) -> some View {
        let color = hitRateColor(rate: rate, ideal: ideal)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(String(format: "%.0f%%", rate * 100))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * min(rate, 1.0), height: 10)
                    // Ideal marker
                    Rectangle()
                        .fill(Color.primary.opacity(0.4))
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width * ideal - 1)
                }
            }
            .frame(height: 10)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Streaks")
                .font(.headline)
                .fontWeight(.bold)

            HStack(spacing: 0) {
                streakStat(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(profile?.currentStreak ?? 0)",
                    label: "Current"
                )
                Divider().frame(height: 48)
                streakStat(
                    icon: "trophy.fill",
                    iconColor: .yellow,
                    value: "\(profile?.longestStreak ?? 0)",
                    label: "Longest"
                )
                Divider().frame(height: 48)
                streakStat(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    value: "\(profile?.totalQuestionsAnswered ?? 0)",
                    label: "Answered"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func streakStat(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        Group {
            if isTodayComplete {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text("Today's set complete")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                NavigationLink(destination: DailySetView()) {
                    HStack {
                        Text("Play today's set")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.headline)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Helpers

    private func calibrationColor(score: Double) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func hitRateColor(rate: Double, ideal: Double) -> Color {
        let error = abs(rate - ideal)
        if error <= 0.10 { return .green }
        if error <= 0.25 { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack {
        CalibrationDashboardView()
    }
    .modelContainer(for: [Answer.self, Question.self, UserProfile.self], inMemory: true)
}
