import SwiftUI
import SwiftData

@main
struct APICraftApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SDCollection.self,
            SDRequest.self,
            SDRequestParameter.self,
            SDTestAssertion.self,
            SDExecutionResult.self,
            SDAssertionLog.self,
            SDEnvironment.self,
            SDEnvironmentVariable.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
