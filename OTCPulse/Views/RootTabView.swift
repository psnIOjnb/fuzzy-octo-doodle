//
//  RootTabView.swift
//  OTC Pulse
//
//  Bottom tab bar with all ten sections. iOS shows the first four plus a
//  system "More" tab that hosts the remainder — every section stays a
//  first-class destination.
//

import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(DataService.self) private var dataService
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Tab bar & navigation bar chrome tuned for the deep-navy theme.
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.043, green: 0.055, blue: 0.10, alpha: 0.98)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(white: 0.93, alpha: 1)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(white: 0.93, alpha: 1)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some View {
        TabView {
            NavigationStack { GlobalView() }
                .tabItem { Label("Global", systemImage: "globe") }

            NavigationStack { RegionsView() }
                .tabItem { Label("Regions", systemImage: "map.fill") }

            NavigationStack { HighImpactView() }
                .tabItem { Label("High Impact", systemImage: "bolt.fill") }

            NavigationStack { SearchView() }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack { RegulatorsView() }
                .tabItem { Label("Regulators", systemImage: "building.columns.fill") }

            NavigationStack { TopicsView() }
                .tabItem { Label("Topics", systemImage: "tag.fill") }

            NavigationStack { DeadlinesView() }
                .tabItem { Label("Deadlines", systemImage: "calendar.badge.clock") }

            NavigationStack { LibraryView() }
                .tabItem { Label("Library", systemImage: "books.vertical.fill") }

            NavigationStack { WatchlistView() }
                .tabItem { Label("Watchlist", systemImage: "star.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .onChange(of: scenePhase) { _, phase in
            // Opportunistic refresh when the app returns to the foreground.
            if phase == .active {
                Task { await dataService.refreshIfStale() }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Publication.self, Regulator.self, DailySnapshot.self, WatchlistItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return RootTabView()
        .environment(DataService(container: container))
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
