import SwiftUI
import SwiftData

struct ContentView: View {
    let storageWarning: String?
    @AppStorage(Constants.UserDefaultsKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var isShowingStorageWarning: Bool

    init(storageWarning: String? = nil) {
        self.storageWarning = storageWarning
        _isShowingStorageWarning = State(initialValue: storageWarning != nil)
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                NavigationStack {
                    CalibrationDashboardView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                NavigationLink {
                                    LeaderboardView()
                                } label: {
                                    Image(systemName: "trophy")
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    SettingsView()
                                } label: {
                                    Image(systemName: "gear")
                                }
                            }
                        }
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .alert("Temporary Storage", isPresented: $isShowingStorageWarning) {
            Button("Continue") {}
        } message: {
            Text(storageWarning ?? "Saved data is temporarily unavailable.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PremiumStore())
        .modelContainer(for: [Answer.self, Question.self, UserProfile.self], inMemory: true)
}
