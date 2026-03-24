import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage(Constants.UserDefaultsKeys.isAdminMode) private var isAdminMode = false
    @Query(filter: #Predicate<Question> { $0.isApproved == true })
    private var approvedQuestions: [Question]
    @State private var tapCount = 0
    @State private var tapResetTask: Task<Void, Never>?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        List {
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            tapCount += 1
                            tapResetTask?.cancel()
                            tapResetTask = Task {
                                try? await Task.sleep(for: .seconds(2))
                                guard !Task.isCancelled else { return }
                                tapCount = 0
                            }
                            if tapCount >= 5 {
                                isAdminMode.toggle()
                                tapCount = 0
                            }
                        }
                }
            }

            if isAdminMode {
                Section("Admin") {
                    NavigationLink("Question Manager") {
                        AdminQuestionView()
                    }
                    HStack {
                        Text("Approved Questions")
                        Spacer()
                        Text("\(approvedQuestions.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
