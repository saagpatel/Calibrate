import SwiftUI

struct TutorialQuestionView: View {
    @AppStorage(Constants.UserDefaultsKeys.hasCompletedOnboarding)
    private var hasCompletedOnboarding = false

    // Interval input state
    @State private var lower90Text = ""
    @State private var lower50Text = ""
    @State private var pointEstimateText = ""
    @State private var upper50Text = ""
    @State private var upper90Text = ""

    @State private var isRevealed = false

    private let truth = Constants.Tutorial.groundTruthValue
    private let unit = Constants.Tutorial.groundTruthUnit
    private let questionText = Constants.Tutorial.questionText
    private let explanation = Constants.Tutorial.explanation

    // Derived widget for validation access
    private var lower90: Double? { Double(lower90Text) }
    private var lower50: Double? { Double(lower50Text) }
    private var pointEstimate: Double? { Double(pointEstimateText) }
    private var upper50: Double? { Double(upper50Text) }
    private var upper90: Double? { Double(upper90Text) }

    private var allFilled: Bool {
        lower90 != nil && lower50 != nil && pointEstimate != nil && upper50 != nil && upper90 != nil
    }

    private var intervalsValid: Bool {
        guard let l90 = lower90, let l50 = lower50, let pe = pointEstimate,
              let u50 = upper50, let u90 = upper90 else { return false }
        return l90 <= l50 && l50 <= pe && pe <= u50 && u50 <= u90
    }

    private var isValid: Bool { allFilled && intervalsValid }

    // Results after lock-in
    private var hit50: Bool {
        guard let l50 = lower50, let u50 = upper50 else { return false }
        return l50 <= truth && truth <= u50
    }

    private var hit90: Bool {
        guard let l90 = lower90, let u90 = upper90 else { return false }
        return l90 <= truth && truth <= u90
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Question header
                questionHeader

                if !isRevealed {
                    // Input form
                    VStack(spacing: 20) {
                        IntervalInputWidget(
                            lower90Text: $lower90Text,
                            lower50Text: $lower50Text,
                            pointEstimateText: $pointEstimateText,
                            upper50Text: $upper50Text,
                            upper90Text: $upper90Text,
                            unit: unit
                        )

                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                isRevealed = true
                            }
                        } label: {
                            Text("Lock In")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isValid ? Color.accentColor : Color(.systemFill))
                                )
                                .foregroundStyle(isValid ? .white : Color(.systemGray))
                        }
                        .disabled(!isValid)
                    }
                } else {
                    // Reveal section
                    revealSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .navigationTitle("Practice Round")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isRevealed)
    }

    // MARK: - Subviews

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Science", systemImage: "atom")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                    )
                Spacer()
                Label("Practice", systemImage: "graduationcap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(questionText)
                .font(.title2)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            Text("Answer in \(unit). Set your confidence intervals below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var revealSection: some View {
        VStack(spacing: 20) {
            // Truth reveal
            VStack(spacing: 8) {
                Text("The Answer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.0)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", truth))
                        .font(.system(size: 64, weight: .black, design: .rounded))
                    Text(unit)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )

            // Interval results
            VStack(spacing: 10) {
                intervalResult(
                    label: "50% Interval",
                    hit: hit50,
                    low: lower50 ?? 0,
                    high: upper50 ?? 0
                )
                intervalResult(
                    label: "90% Interval",
                    hit: hit90,
                    low: lower90 ?? 0,
                    high: upper90 ?? 0
                )
            }

            // Explanation
            VStack(alignment: .leading, spacing: 10) {
                Label("Explanation", systemImage: "lightbulb")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)

                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                    )
            )

            // Calibration hint
            calibrationHint

            // CTA
            Button {
                hasCompletedOnboarding = true
            } label: {
                HStack {
                    Text("Got it — Let's play!")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.right")
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

    private func intervalResult(label: String, hit: Bool, low: Double, high: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(String(format: "%.0f", low)) – \(String(format: "%.0f", high)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(hit ? .green : .red)
                Text(hit ? "Contains truth" : "Missed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(hit ? .green : .red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var calibrationHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What this means", systemImage: "info.circle")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)

            Text("Over many questions, your 50% intervals should contain the truth ~half the time, and your 90% intervals ~9 in 10 times. That's good calibration.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.blue.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    NavigationStack {
        TutorialQuestionView()
    }
}
