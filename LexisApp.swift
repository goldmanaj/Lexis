import SwiftUI

@main
struct LexisApp: App {
    @StateObject private var store = WordStore()

    init() {
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
                .preferredColorScheme(.dark)
                .onAppear {
                    Task { await store.fetchTodayWordIfNeeded() }
                    NotificationManager.shared.requestPermission()
                }
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
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
    }
}
