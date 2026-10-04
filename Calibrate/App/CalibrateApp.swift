import SwiftUI
import SwiftData

@main
struct CalibrateApp: App {
    let modelContainer: ModelContainer
    let storageWarning: String?
    @StateObject private var premiumStore = PremiumStore()

    init() {
        let schema = Schema([
            Question.self,
            DailySet.self,
            Answer.self,
            UserProfile.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            // Manual CK sync via UserService/LeaderboardService.
            // Not using automatic SwiftData-CK sync — we selectively sync
            // answers/profile to private DB and read questions from public DB.
            cloudKitDatabase: .none
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            storageWarning = nil
        } catch {
            do {
                let fallback = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                modelContainer = try ModelContainer(for: schema, configurations: [fallback])
                storageWarning = "Calibrate could not open its saved data. You can keep using this session, but new progress will not be preserved after the app closes."
            } catch {
                fatalError("Failed to create persistent or temporary ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(storageWarning: storageWarning)
                .environmentObject(premiumStore)
                .task {
                    await seedAndSetupIfNeeded()
                    await premiumStore.load()
                }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func seedAndSetupIfNeeded() async {
        let context = modelContainer.mainContext

        if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasSeededQuestions) {
            do {
                _ = try ImportService.importFromBundle(
                    filename: "seed_questions",
                    autoApprove: true,
                    into: context
                )
                #if DEBUG
                print("[Calibrate] Seeded bundled questions")
                #endif
                let profiles = try context.fetch(FetchDescriptor<UserProfile>())
                if profiles.isEmpty {
                    context.insert(UserProfile(displayName: "Player"))
                    try context.save()
                }
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasSeededQuestions)
            } catch {
                // Leave the flag unset so the idempotent setup retries next launch.
                #if DEBUG
                print("[Calibrate] Initial content setup failed: \(error)")
                #endif
            }
        }

        if UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.dailyReminderEnabled) {
            await NotificationScheduler.scheduleIfAuthorized()
        }
    }
}
