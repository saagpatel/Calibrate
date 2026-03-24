import SwiftUI

struct QuestionCategoryTag: View {
    let category: String

    private var color: Color {
        switch category {
        case "geography": .blue
        case "science": .green
        case "economics": .orange
        case "history": .brown
        case "popCulture": .purple
        case "currentEvents": .red
        default: .gray
        }
    }

    var body: some View {
        Text(category)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 8) {
        QuestionCategoryTag(category: "geography")
        QuestionCategoryTag(category: "science")
        QuestionCategoryTag(category: "economics")
        QuestionCategoryTag(category: "history")
        QuestionCategoryTag(category: "popCulture")
        QuestionCategoryTag(category: "currentEvents")
        QuestionCategoryTag(category: "unknown")
    }
    .padding()
}
