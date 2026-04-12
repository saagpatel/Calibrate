import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var premiumStore: PremiumStore
    @AppStorage(Constants.UserDefaultsKeys.isAdminMode) private var isAdminMode = false
    @Query(filter: #Predicate<Question> { $0.isApproved == true })
    private var approvedQuestions: [Question]
    @State private var tapCount = 0
    @State private var tapResetTask: Task<Void, Never>?
    @State private var showUpgrade = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        List {
            if !premiumStore.isPremium {
                Section {
                    Button {
                        showUpgrade = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Premium")
                                    .fontWeight(.semibold)
                                Text("Advanced calibration curve, friend groups & more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                }
            }

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
        .sheet(isPresented: $showUpgrade) {
            PremiumUpgradeView()
                .environmentObject(premiumStore)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(PremiumStore())
}
