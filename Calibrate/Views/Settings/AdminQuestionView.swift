import SwiftUI
import SwiftData

struct AdminQuestionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Question> { $0.isApproved == false },
           sort: \Question.createdAt, order: .reverse)
    private var pendingQuestions: [Question]

    @Query(filter: #Predicate<Question> { $0.isApproved == true })
    private var approvedQuestions: [Question]

    @State private var importResult: String?
    @State private var showingImportAlert = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Pending", systemImage: "clock")
                    Spacer()
                    Text("\(pendingQuestions.count)")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Label("Approved", systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(approvedQuestions.count)")
                        .foregroundStyle(.green)
                }
                Button("Import from Bundle") {
                    importQuestions()
                }
            } header: {
                Text("Overview")
            }

            Section {
                if pendingQuestions.isEmpty {
                    ContentUnavailableView(
                        "No Pending Questions",
                        systemImage: "tray",
                        description: Text("Import questions or generate new ones with the Python CLI.")
                    )
                } else {
                    ForEach(pendingQuestions, id: \.id) { question in
                        QuestionReviewRow(question: question) {
                            approveQuestion(question)
                        } onReject: {
                            rejectQuestion(question)
                        }
                    }
                }
            } header: {
                Text("Pending Review")
            }
        }
        .navigationTitle("Question Manager")
        .alert("Import Result", isPresented: $showingImportAlert) {
            Button("OK") {}
        } message: {
            Text(importResult ?? "")
        }
    }

    private func importQuestions() {
        do {
            let count = try ImportService.importFromBundle(into: modelContext)
            importResult = "Imported \(count) new questions."
        } catch {
            importResult = "Import failed: \(error.localizedDescription)"
        }
        showingImportAlert = true
    }

    private func approveQuestion(_ question: Question) {
        question.isApproved = true
        try? modelContext.save()
    }

    private func rejectQuestion(_ question: Question) {
        modelContext.delete(question)
        try? modelContext.save()
    }
}

private struct QuestionReviewRow: View {
    let question: Question
    let onApprove: () -> Void
    let onReject: () -> Void
    @State private var difficulty: Double

    init(question: Question, onApprove: @escaping () -> Void, onReject: @escaping () -> Void) {
        self.question = question
        self.onApprove = onApprove
        self.onReject = onReject
        self._difficulty = State(initialValue: question.difficulty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.text)
                .font(.headline)

            HStack {
                QuestionCategoryTag(category: question.category)
                Spacer()
                Text("\(question.groundTruthValue, specifier: "%.2f") \(question.groundTruthUnit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let url = URL(string: question.sourceURL) {
                Link(question.sourceURL, destination: url)
                    .font(.caption)
                    .lineLimit(1)
            }

            Text(question.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Difficulty")
                    .font(.caption)
                Slider(value: $difficulty, in: 0...1, step: 0.1)
                    .onChange(of: difficulty) { _, newValue in
                        question.difficulty = newValue
                    }
                Text(String(format: "%.1f", difficulty))
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 12) {
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AdminQuestionView()
    }
}
