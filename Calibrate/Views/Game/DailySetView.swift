import SwiftUI
import SwiftData

// MARK: - AnswerDraft

struct AnswerDraft {
    let lower90: Double
    let lower50: Double
    let pointEstimate: Double
    let upper50: Double
    let upper90: Double
}

// MARK: - DailySetView

struct DailySetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAnswers: [Answer]
    @Query private var profiles: [UserProfile]

    @State private var currentIndex = 0
    @State private var answerDrafts: [AnswerDraft?] = Array(repeating: nil, count: Constants.Calibration.questionsPerDay)

    // Per-question text fields (5 each)
    @State private var lower90Texts: [String] = Array(repeating: "", count: Constants.Calibration.questionsPerDay)
    @State private var lower50Texts: [String] = Array(repeating: "", count: Constants.Calibration.questionsPerDay)
    @State private var pointEstimateTexts: [String] = Array(repeating: "", count: Constants.Calibration.questionsPerDay)
    @State private var upper50Texts: [String] = Array(repeating: "", count: Constants.Calibration.questionsPerDay)
    @State private var upper90Texts: [String] = Array(repeating: "", count: Constants.Calibration.questionsPerDay)
    @State private var isLocked: [Bool] = Array(repeating: false, count: Constants.Calibration.questionsPerDay)

    @State private var showResults = false
    @State private var submittedAnswers: [Answer] = []
    @State private var scoreDelta: Double? = nil
    @State private var questions: [Question] = []
    @State private var dailySet: DailySet? = nil
    @State private var alreadyCompleted = false
    @State private var loadError: String? = nil

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Group {
            if let error = loadError {
                errorView(message: error)
            } else if alreadyCompleted {
                alreadyCompletedView
            } else if questions.isEmpty {
                loadingView
            } else if showResults {
                ResultsView(
                    questions: questions,
                    answers: submittedAnswers,
                    scoreDelta: scoreDelta
                )
            } else {
                gameView
            }
        }
        .navigationTitle("Today's Questions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDailySet()
        }
    }

    // MARK: - Sub-views

    private var gameView: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Divider()

            if currentIndex < questions.count {
                let q = questions[currentIndex]
                QuestionCardView(
                    question: q,
                    lower90Text: $lower90Texts[currentIndex],
                    lower50Text: $lower50Texts[currentIndex],
                    pointEstimateText: $pointEstimateTexts[currentIndex],
                    upper50Text: $upper50Texts[currentIndex],
                    upper90Text: $upper90Texts[currentIndex],
                    isLocked: isLocked[currentIndex],
                    onLockIn: { lockIn(questionIndex: currentIndex) }
                )
                .id(currentIndex)
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(currentIndex + 1) of \(Constants.Calibration.questionsPerDay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(
                            width: geo.size.width * progressFraction,
                            height: 6
                        )
                        .animation(.spring(duration: 0.4), value: currentIndex)
                }
            }
            .frame(height: 6)
        }
    }

    private var progressFraction: CGFloat {
        let total = CGFloat(Constants.Calibration.questionsPerDay)
        guard total > 0 else { return 0 }
        return CGFloat(currentIndex + 1) / total
    }

    private var alreadyCompletedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("You've completed today's questions")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Come back in \(timeUntilUTCMidnight)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Loading today's questions…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "Couldn't Load Questions",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    // MARK: - Actions

    private func loadDailySet() async {
        let today = DateUtils.currentUTCDate()

        // Check replay guard
        if let prof = profile, prof.lastCompletedUTCDate == today {
            alreadyCompleted = true
            return
        }

        do {
            let set = try QuestionService.fetchDailySet(for: today, in: modelContext)
            let qs = try QuestionService.fetchQuestions(for: set, in: modelContext)
            dailySet = set
            questions = qs
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func lockIn(questionIndex: Int) {
        guard questionIndex < questions.count else { return }
        guard
            let l90 = Double(lower90Texts[questionIndex]),
            let l50 = Double(lower50Texts[questionIndex]),
            let pe  = Double(pointEstimateTexts[questionIndex]),
            let u50 = Double(upper50Texts[questionIndex]),
            let u90 = Double(upper90Texts[questionIndex])
        else { return }

        let draft = AnswerDraft(lower90: l90, lower50: l50, pointEstimate: pe, upper50: u50, upper90: u90)
        answerDrafts[questionIndex] = draft

        isLocked[questionIndex] = true

        let isLastQuestion = questionIndex == Constants.Calibration.questionsPerDay - 1

        if isLastQuestion {
            submitAll()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex = questionIndex + 1
            }
        }
    }

    private func submitAll() {
        let compactDrafts = answerDrafts.compactMap { $0 }
        guard compactDrafts.count == Constants.Calibration.questionsPerDay,
              questions.count == Constants.Calibration.questionsPerDay else { return }

        let today = DateUtils.currentUTCDate()

        // Compute "before" score from all historical answers
        let historicalAnswerWithTruths = buildHistoricalAnswerWithTruths()
        let beforeResult = CalibrationEngine.calibrationResult(answers: historicalAnswerWithTruths)
        let beforeScore: Double
        if case .result(let data) = beforeResult {
            beforeScore = data.score
        } else {
            beforeScore = -1 // sentinel: no score yet
        }

        // Write 5 Answer records
        var newAnswers: [Answer] = []
        for (i, draft) in compactDrafts.enumerated() {
            let q = questions[i]
            let answer = Answer(
                questionID: q.id,
                utcDate: today,
                pointEstimate: draft.pointEstimate,
                lower50: draft.lower50,
                upper50: draft.upper50,
                lower90: draft.lower90,
                upper90: draft.upper90
            )
            modelContext.insert(answer)
            newAnswers.append(answer)
        }

        // Compute "after" score including the new answers
        let newAnswerWithTruths = zip(compactDrafts, questions).map { draft, q in
            AnswerWithTruth(
                lower50: draft.lower50,
                upper50: draft.upper50,
                lower90: draft.lower90,
                upper90: draft.upper90,
                pointEstimate: draft.pointEstimate,
                truth: q.groundTruthValue
            )
        }
        let combined = historicalAnswerWithTruths + newAnswerWithTruths
        let afterResult = CalibrationEngine.calibrationResult(answers: combined)

        if case .result(let afterData) = afterResult {
            if beforeScore < 0 {
                scoreDelta = nil // "First score!"
            } else {
                scoreDelta = afterData.score - beforeScore
            }
        } else {
            scoreDelta = nil
        }

        // Update UserProfile streak and metadata
        if let prof = profile {
            let gap = DateUtils.daysBetween(from: prof.lastCompletedUTCDate, to: today)
            if gap == 1 {
                prof.currentStreak += 1
            } else if gap != 0 {
                prof.currentStreak = 1
            }
            prof.longestStreak = max(prof.longestStreak, prof.currentStreak)
            prof.lastCompletedUTCDate = today
            prof.totalQuestionsAnswered += Constants.Calibration.questionsPerDay
        }

        do {
            try modelContext.save()
        } catch {
            // Non-fatal: answers are in memory; log and continue
            print("[DailySetView] modelContext.save failed: \(error)")
        }

        submittedAnswers = newAnswers
        showResults = true
    }

    private func buildHistoricalAnswerWithTruths() -> [AnswerWithTruth] {
        // Build a lookup from questionID → groundTruthValue
        var truthMap: [UUID: Double] = [:]
        for q in questions {
            truthMap[q.id] = q.groundTruthValue
        }
        // Also fetch all questions to resolve older answers
        let allQs: [Question]
        do {
            allQs = try modelContext.fetch(FetchDescriptor<Question>())
        } catch {
            return []
        }
        for q in allQs {
            truthMap[q.id] = q.groundTruthValue
        }

        return allAnswers.compactMap { answer -> AnswerWithTruth? in
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
    }

    // MARK: - Helpers

    private var timeUntilUTCMidnight: String {
        let now = Date()
        var components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone.gmt, from: now)
        components.hour = 23
        components.minute = 59
        components.second = 59
        guard let endOfDay = Calendar(identifier: .gregorian).date(from: components) else {
            return "a few hours"
        }
        let seconds = Int(endOfDay.timeIntervalSince(now)) + 1
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
