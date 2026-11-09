import SwiftUI
import SwiftData

@main
struct APICraftApp: App {
    @State private var isSplashActive = true
    
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
                .environment(\.locale, Locale(identifier: "en_US"))
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Splash Screen / Launch Screen View
public struct SplashScreenView: View {
    @Binding var isActive: Bool
    
    @State private var logoScale: CGFloat = 0.85
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var progress: Double = 0.0
    @State private var statusText: String = "Initializing API Engine..."
    
    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }
    
    public var body: some View {
        ZStack {
            // Deep Cyber Background
            Color.black
                .ignoresSafeArea()
            
            // Static ambient gradient glow (no infinite rotation to prevent layer decomposition faults)
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: -50, y: -60)
                
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: 60, y: 60)
            }
            
            VStack(spacing: 24) {
                Spacer()
                
                // App Icon / Logo
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .blur(radius: 3)
                        .opacity(logoOpacity * 0.7)
                    
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .cyan.opacity(0.35), radius: 12, y: 4)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App Title & Tagline
                VStack(spacing: 6) {
                    Text("APICraft")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Fast • Native • Modern API Client")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(textOpacity)
                
                Spacer()
                
                // Loading Bar & Status
                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 140, height: 3)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 140 * progress, height: 3)
                            .animation(.easeOut(duration: 0.25), value: progress)
                    }
                    
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(textOpacity)
                .padding(.bottom, 36)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissSplash()
        }
        .onAppear {
            runAnimationSequence()
        }
    }
    
    private func runAnimationSequence() {
        withAnimation(.easeOut(duration: 0.2)) {
            logoScale = 1.0
            logoOpacity = 1.0
            textOpacity = 1.0
            progress = 1.0
            statusText = "Ready"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismissSplash()
        }
    }
    
    private func dismissSplash() {
        guard isActive else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isActive = false
        }
    }
}
