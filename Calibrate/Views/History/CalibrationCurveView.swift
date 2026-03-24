import SwiftUI
import Charts

struct CalibrationCurveView: View {
    let answersWithTruth: [AnswerWithTruth]

    private var reliabilityPoints: [(stated: Double, observed: Double)] {
        CalibrationEngine.reliabilityPoints(answers: answersWithTruth)
    }

    private var interpretationText: String {
        guard !reliabilityPoints.isEmpty else { return "" }

        let avg50Error = reliabilityPoints.first(where: { $0.stated == 0.50 }).map { $0.observed - 0.50 } ?? 0
        let avg90Error = reliabilityPoints.first(where: { $0.stated == 0.90 }).map { $0.observed - 0.90 } ?? 0
        let avgError = (avg50Error + avg90Error) / 2.0

        if abs(avgError) <= 0.05 {
            return "Well calibrated — your stated confidence matches your observed accuracy."
        } else if avgError < 0 {
            return "Overconfident — your intervals miss more often than expected. Try wider intervals."
        } else {
            return "Underconfident — your intervals capture the truth more than stated. Try narrower intervals."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            chartSection
            if !reliabilityPoints.isEmpty {
                legendSection
                interpretationSection
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Calibration Curve")
                .font(.headline)
                .fontWeight(.bold)
            Text("Stated confidence vs. observed accuracy")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart

    private var chartSection: some View {
        Group {
            if reliabilityPoints.isEmpty {
                insufficientDataView
            } else {
                calibrationChart
            }
        }
        .frame(height: 280)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var insufficientDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Need \(Constants.Calibration.minimumSampleSize) answers")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("\(answersWithTruth.count) of \(Constants.Calibration.minimumSampleSize) completed")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calibrationChart: some View {
        Chart {
            // Reference diagonal (perfect calibration)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { value in
                LineMark(
                    x: .value("Stated", value),
                    y: .value("Observed", value)
                )
                .foregroundStyle(Color(.systemGray3))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .interpolationMethod(.linear)
            }

            // Connecting line between data points
            ForEach(reliabilityPoints, id: \.stated) { point in
                LineMark(
                    x: .value("Stated", point.stated),
                    y: .value("Observed", point.observed)
                )
                .foregroundStyle(Color.accentColor.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.linear)
            }

            // Data points — amber for 50%, blue for 90%
            ForEach(reliabilityPoints.filter { $0.stated == 0.50 }, id: \.stated) { point in
                PointMark(
                    x: .value("Stated", point.stated),
                    y: .value("Observed", point.observed)
                )
                .foregroundStyle(Color.amber)
                .symbolSize(180)
                .annotation(position: .top, spacing: 6) {
                    VStack(spacing: 1) {
                        Text("\(Int(point.stated * 100))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.amber)
                        Text("→\(Int(point.observed * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(reliabilityPoints.filter { $0.stated == 0.90 }, id: \.stated) { point in
                PointMark(
                    x: .value("Stated", point.stated),
                    y: .value("Observed", point.observed)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(180)
                .annotation(position: .top, spacing: 6) {
                    VStack(spacing: 1) {
                        Text("\(Int(point.stated * 100))%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.blue)
                        Text("→\(Int(point.observed * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXScale(domain: 0...1)
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d * 100))%")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 0.25, 0.5, 0.75, 1.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text("\(Int(d * 100))%")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxisLabel("Stated Confidence", alignment: .center)
        .chartYAxisLabel("Observed Accuracy", position: .leading, alignment: .center)
    }

    // MARK: - Legend

    private var legendSection: some View {
        HStack(spacing: 20) {
            legendItem(color: Color.amber, symbol: "circle.fill", label: "50% interval")
            legendItem(color: .blue, symbol: "circle.fill", label: "90% interval")
            HStack(spacing: 6) {
                dashLine
                Text("Perfect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func legendItem(color: Color, symbol: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dashLine: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(Color(.systemGray3))
                    .frame(width: 4, height: 1.5)
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2, height: 1.5)
            }
        }
    }

    // MARK: - Interpretation

    private var interpretationSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.subheadline)

            Text(interpretationText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ScrollView {
        CalibrationCurveView(answersWithTruth: [
            AnswerWithTruth(lower50: 80, upper50: 120, lower90: 60, upper90: 150, pointEstimate: 100, truth: 95),
            AnswerWithTruth(lower50: 200, upper50: 300, lower90: 150, upper90: 350, pointEstimate: 250, truth: 400),
            AnswerWithTruth(lower50: 5, upper50: 15, lower90: 2, upper90: 20, pointEstimate: 10, truth: 8),
            AnswerWithTruth(lower50: 1000, upper50: 2000, lower90: 500, upper90: 3000, pointEstimate: 1500, truth: 1200),
            AnswerWithTruth(lower50: 30, upper50: 70, lower90: 10, upper90: 100, pointEstimate: 50, truth: 45)
        ])
        .padding(20)
    }
}
