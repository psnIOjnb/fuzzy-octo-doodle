//
//  DayPageApp.swift
//  DayPage
//
//  App entry point: one SwiftData container, one navigation store, one
//  settings object. There is no networking layer because there is nothing
//  to talk to — the whole app is the local store.
//

import SwiftUI
import SwiftData

@main
struct DayPageApp: App {

    /// Everything the app knows, stored on-device.
    let container: ModelContainer

    @State private var settings: AppSettings
    @State private var store: DayStore

    init() {
        let schema = Schema([AgendaItem.self, DailyNote.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }

        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _store = State(initialValue: DayStore(startsCollapsed: settings.agendaStartsCollapsed))
    }

    var body: some Scene {
        WindowGroup {
            DayView()
                .environment(store)
                .environment(settings)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
