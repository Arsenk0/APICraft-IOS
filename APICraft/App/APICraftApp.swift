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
            print("⚠️ SwiftData ModelContainer failed (schema mismatch): \(error)")
            // Remove old SQLite store if schema changed during development
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            let shm = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let wal = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? FileManager.default.removeItem(at: shm)
            try? FileManager.default.removeItem(at: wal)
            
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                print("⚠️ Fallback to in-memory container: \(error)")
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let container = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) {
                    return container
                }
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
