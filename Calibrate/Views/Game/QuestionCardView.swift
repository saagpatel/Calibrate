import SwiftUI

struct QuestionCardView: View {
    let question: Question
    @Binding var lower90Text: String
    @Binding var lower50Text: String
    @Binding var pointEstimateText: String
    @Binding var upper50Text: String
    @Binding var upper90Text: String
    let isLocked: Bool
    let onLockIn: () -> Void

    // Mirror validation state from the widget
    private var widgetIsValid: Bool {
        guard
            let l90 = Double(lower90Text),
            let l50 = Double(lower50Text),
            let pe  = Double(pointEstimateText),
            let u50 = Double(upper50Text),
            let u90 = Double(upper90Text)
        else { return false }
        return l90 <= l50 && l50 <= pe && pe <= u50 && u50 <= u90
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Question text
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)

                // Category + unit hint
                HStack(spacing: 10) {
                    QuestionCategoryTag(category: question.category)
                    Spacer()
                }

                Text("Your answer will be in: \(question.groundTruthUnit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isLocked {
                    lockedValuesView
                } else {
                    IntervalInputWidget(
                        lower90Text: $lower90Text,
                        lower50Text: $lower50Text,
                        pointEstimateText: $pointEstimateText,
                        upper50Text: $upper50Text,
                        upper90Text: $upper90Text,
                        unit: question.groundTruthUnit
                    )
                }

                Button(action: onLockIn) {
                    HStack {
                        Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                        Text(isLocked ? "Locked In" : "Lock In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!widgetIsValid || isLocked)
                .animation(.easeInOut(duration: 0.15), value: isLocked)
            }
            .padding(20)
        }
    }

    // MARK: - Locked values read-only display

    @ViewBuilder
    private var lockedValuesView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                lockedRow(label: "90% Lower Bound", value: lower90Text, unit: question.groundTruthUnit, color: .blue)

                VStack(spacing: 8) {
                    lockedRow(label: "50% Lower Bound", value: lower50Text, unit: question.groundTruthUnit, color: Color.amber)

                    lockedRow(label: "Best Estimate", value: pointEstimateText, unit: question.groundTruthUnit, color: .primary)

                    lockedRow(label: "50% Upper Bound", value: upper50Text, unit: question.groundTruthUnit, color: Color.amber)
                }
                .padding(12)
                .background(Color.orange.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                lockedRow(label: "90% Upper Bound", value: upper90Text, unit: question.groundTruthUnit, color: .blue)
            }
            .padding(14)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }

    @ViewBuilder
    private func lockedRow(label: String, value: String, unit: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Spacer()
            Text("\(value) \(unit)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
