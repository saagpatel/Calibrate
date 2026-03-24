import SwiftUI

struct IntervalInputWidget: View {
    @Binding var lower90Text: String
    @Binding var lower50Text: String
    @Binding var pointEstimateText: String
    @Binding var upper50Text: String
    @Binding var upper90Text: String
    let unit: String

    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case lower90, lower50, pointEstimate, upper50, upper90
    }

    // MARK: - Validation

    var isValid: Bool {
        guard let l90 = Double(lower90Text),
              let l50 = Double(lower50Text),
              let pe = Double(pointEstimateText),
              let u50 = Double(upper50Text),
              let u90 = Double(upper90Text) else { return false }
        return l90 <= l50 && l50 <= pe && pe <= u50 && u50 <= u90
    }

    var validationMessage: String? {
        guard let l90 = Double(lower90Text),
              let l50 = Double(lower50Text),
              let pe = Double(pointEstimateText),
              let u50 = Double(upper50Text),
              let u90 = Double(upper90Text) else { return nil }
        if l90 > l50 { return "90% lower must be ≤ 50% lower bound" }
        if l50 > pe  { return "50% lower must be ≤ best estimate" }
        if pe > u50  { return "Best estimate must be ≤ 50% upper bound" }
        if u50 > u90 { return "50% upper must be ≤ 90% upper bound" }
        return nil
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            outerZone
            validationError
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    // MARK: - Sub-views

    private var outerZone: some View {
        VStack(spacing: 8) {
            intervalRow(label: "90% Lower Bound", placeholder: "e.g. 100",
                        text: $lower90Text, field: .lower90, tint: .blue)
            innerZone
            intervalRow(label: "90% Upper Bound", placeholder: "e.g. 250",
                        text: $upper90Text, field: .upper90, tint: .blue)
        }
        .padding(14)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.blue.opacity(0.3), lineWidth: 1))
    }

    private var innerZone: some View {
        VStack(spacing: 8) {
            intervalRow(label: "50% Lower Bound", placeholder: "e.g. 150",
                        text: $lower50Text, field: .lower50, tint: Color.amber)
            pointEstimateRow
            intervalRow(label: "50% Upper Bound", placeholder: "e.g. 200",
                        text: $upper50Text, field: .upper50, tint: Color.amber)
        }
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private var pointEstimateRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Best Estimate")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("e.g. 175", text: $pointEstimateText)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .pointEstimate)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
    }

    @ViewBuilder
    private var validationError: some View {
        if let message = validationMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Row helper

    private func intervalRow(
        label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        tint: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(tint)
                Spacer()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: field)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospacedDigit())
        }
    }
}

extension Color {
    static let amber = Color(red: 1.0, green: 0.6, blue: 0.0)
}

#Preview {
    @Previewable @State var l90 = ""
    @Previewable @State var l50 = ""
    @Previewable @State var pe = ""
    @Previewable @State var u50 = ""
    @Previewable @State var u90 = ""

    ScrollView {
        IntervalInputWidget(
            lower90Text: $l90,
            lower50Text: $l50,
            pointEstimateText: $pe,
            upper50Text: $u50,
            upper90Text: $u90,
            unit: "km"
        )
        .padding()
    }
}
