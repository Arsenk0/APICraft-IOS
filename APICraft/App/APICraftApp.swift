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
            ZStack {
                MainTabView()
                    .environment(\.locale, Locale(identifier: "en_US"))
                
                if isSplashActive {
                    SplashScreenView(isActive: $isSplashActive)
                        .transition(.opacity.combined(with: .scale(scale: 1.03)))
                        .zIndex(999)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Splash Screen / Launch Screen View
public struct SplashScreenView: View {
    @Binding var isActive: Bool
    
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var glowRotation: Double = 0.0
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
            
            // Ambient glowing gradient orbs
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -60, y: -80)
                
                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 70, y: 70)
            }
            .rotationEffect(.degrees(glowRotation))
            
            VStack(spacing: 24) {
                Spacer()
                
                // Animated App Icon / Logo
                ZStack {
                    // Pulsing outer glow ring
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 124, height: 124)
                        .blur(radius: 4)
                        .scaleEffect(logoScale * 1.05)
                        .opacity(logoOpacity * 0.8)
                    
                    // Main App Logo
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(color: .cyan.opacity(0.4), radius: 16, y: 6)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // App Title & Tagline
                VStack(spacing: 8) {
                    Text("APICraft")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Fast • Native • Modern API Client")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .opacity(textOpacity)
                
                Spacer()
                
                // Futuristic Loading Bar & Status
                VStack(spacing: 10) {
                    // Slim Progress Bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 160, height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 160 * progress, height: 4)
                            .animation(.easeOut(duration: 0.3), value: progress)
                    }
                    
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(textOpacity)
                .padding(.bottom, 40)
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // 1. Logo pop-in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 2. Slow rotation of glow
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            glowRotation = 360
        }
        
        // 3. Fade in text & initial progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.4)) {
                textOpacity = 1.0
                progress = 0.4
            }
        }
        
        // 4. Progress advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                progress = 0.8
                statusText = "Loading Environment & Schemas..."
            }
        }
        
        // 5. Ready and dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation {
                progress = 1.0
                statusText = "Ready"
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            dismissSplash()
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.35)) {
            isActive = false
        }
    }
}
