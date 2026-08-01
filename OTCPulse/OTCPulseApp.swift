//
//  OTCPulseApp.swift
//  OTC Pulse
//
//  App entry point. Sets up the SwiftData container, the shared data
//  service, and forces the dark "intelligence platform" appearance.
//

import SwiftUI
import SwiftData

@main
struct OTCPulseApp: App {

    /// Single SwiftData container holding the entire accumulated history.
    /// Everything is stored on-device; the app is fully usable offline.
    let container: ModelContainer

    /// App-wide data orchestrator (ingest, merge, dedupe, snapshots).
    @State private var dataService: DataService

    init() {
        let schema = Schema([
            Publication.self,
            Regulator.self,
            DailySnapshot.self,
            WatchlistItem.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        _dataService = State(initialValue: DataService(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(dataService)
                .preferredColorScheme(.dark)   // strict dark mode
                .tint(Theme.accent)
                .task {
                    // First launch: seed regulators + 30 days of history,
                    // then ingest "today's" feed so the app is instantly usable.
                    await dataService.bootstrapIfNeeded()
                }
        }
        .modelContainer(container)
    }
}
