import SwiftUI
import GoogleMobileAds
#if canImport(FoundationModels)
import FoundationModels
#endif

@main
struct LexisApp: App {
    @StateObject private var store = WordStore()
    @StateObject private var engine = LayoutEngine()

    init() {
        // Initialize AdMob
        MobileAds.shared.start(completionHandler: nil)

        // Style the tab bar to match the dark theme
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.lexisBg)
        tabBarAppearance.shadowColor = UIColor(Color.lexisBorder)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(Color.lexisSubtle)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.lexisSubtle)]
        itemAppearance.selected.iconColor = UIColor(Color.lexisGold)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.lexisGold)]

        tabBarAppearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(engine)
                .preferredColorScheme(.dark)
                .onAppear {
                    Analytics.shared.logEvent("AppLaunched")
                    if LexisDemoMode.isEnabled {
                        Task { @MainActor in
                            store.seedInvestorDemoData()
                        }
                        return
                    }

                    Task {
                        // Fetch word, ads, and layouts concurrently
                        async let wordFetch: () = store.fetchTodayWordIfNeeded()
                        async let layoutFetch: () = engine.fetchLayouts()
                        
                        // Preload ads
                        AdService.shared.preloadAd(for: "today_footer")
                        AdService.shared.preloadAd(for: "archive_interstitial")
                        
                        _ = await (wordFetch, layoutFetch)

                        NotificationManager.shared.requestPermission()
                    }
                }
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @State private var showAIPrompt = false
    
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "book")
                }

            ArchiveView()
                .tabItem {
                    Label("Archive", systemImage: "clock")
                }

            QuizView()
                .tabItem {
                    Label("Quiz", systemImage: "questionmark.circle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .tint(.lexisGold)
        .onAppear {
            checkAppleIntelligenceStatus()
        }
        .alert("Apple Intelligence Disabled", isPresented: $showAIPrompt) {
            Button("Dismiss", role: .cancel) {
                Analytics.shared.logEvent("AIPromptDismissed")
            }
        } message: {
            Text("Your device supports Apple Intelligence, but it's currently turned off in Settings. Enable it to generate fresh daily vocabulary, or dismiss to use the built-in offline word bank.")
        }
    }

    private func checkAppleIntelligenceStatus() {
        guard !LexisDemoMode.isEnabled else { return }

        #if canImport(FoundationModels)
        if #available(iOS 18.2, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .unavailable(let reason):
                if reason == .appleIntelligenceNotEnabled {
                    Analytics.shared.logEvent("AIPromptShown")
                    showAIPrompt = true
                }
            default:
                break
            }
        }
        #endif
    }
}
