import SwiftUI
import SwiftData
import CloudKit

@main
struct CalibrateApp: App {
    let modelContainer: ModelContainer

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
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Register CloudKit container so it appears in CloudKit Dashboard
        _ = CKContainer(identifier: Constants.CloudKit.containerID)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await seedAndSetupIfNeeded()
                }
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func seedAndSetupIfNeeded() async {
        let context = modelContainer.mainContext

        if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasSeededQuestions) {
            do {
                let count = try ImportService.importFromBundle(
                    filename: "seed_questions",
                    autoApprove: true,
                    into: context
                )
                print("[Calibrate] Seeded \(count) questions")
            } catch {
                print("[Calibrate] Seed import failed: \(error)")
            }

            do {
                let profiles = try context.fetch(FetchDescriptor<UserProfile>())
                if profiles.isEmpty {
                    context.insert(UserProfile(displayName: "Player"))
                    try context.save()
                }
            } catch {
                print("[Calibrate] UserProfile setup failed: \(error)")
            }

            UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasSeededQuestions)
        }

        await NotificationScheduler.requestPermissionAndSchedule()
    }
}
