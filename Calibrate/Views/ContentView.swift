import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(Constants.UserDefaultsKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false

    var body: some View {
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
}

#Preview {
    ContentView()
        .modelContainer(for: [Answer.self, Question.self, UserProfile.self], inMemory: true)
}
