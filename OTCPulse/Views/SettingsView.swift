//
//  SettingsView.swift
//  OTC Pulse
//
//  Feed configuration, manual refresh, notifications, storage management
//  and about. The feed URL is optional — empty means demo/mock mode.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(DataService.self) private var dataService

    @AppStorage(AppConfig.feedURLKey) private var feedURL = ""
    @AppStorage(AppConfig.notificationsEnabledKey) private var notificationsEnabled = false

    @State private var showEraseConfirm = false
    @State private var isWorking = false

    @Query private var allPublications: [Publication]
    @Query private var snapshots: [DailySnapshot]
    @Query private var watchlist: [WatchlistItem]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Form {
                // MARK: Data feed
                Section {
                    TextField("https://your-host/daily.json", text: $feedURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.callout.monospaced())

                    Button {
                        Task {
                            isWorking = true
                            await dataService.refresh()
                            isWorking = false
                        }
                    } label: {
                        HStack {
                            Label("Refresh Now", systemImage: "arrow.clockwise")
                            Spacer()
                            if isWorking || dataService.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(dataService.isRefreshing)

                    if let last = dataService.lastRefresh {
                        LabeledContent("Last refresh") {
                            Text(last, format: .relative(presentation: .named))
                        }
                        .font(.caption)
                    }
                    if let error = dataService.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                    }
                } header: {
                    Text("Daily Feed")
                } footer: {
                    Text("Leave empty to use the built-in OTC Pulse cloud feed, regenerated daily at 20:30 UTC from official regulator sources (CFTC, ESMA, FCA, BoE, FSB, BCBS…). Enter a URL only to override it with your own JSON endpoint. Data merges with deduplication — refreshing twice never duplicates records.")
                }

                // MARK: Notifications
                Section {
                    Toggle("High-impact alerts", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await NotificationManager.requestAuthorization()
                                    if !granted { notificationsEnabled = false }
                                }
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Local notification when a refresh ingests publications with impact score ≥ \(Formatters.score(AppConfig.highImpactThreshold)). Nothing leaves your device.")
                }

                // MARK: Storage
                Section {
                    LabeledContent("Publications", value: "\(allPublications.count)")
                    LabeledContent("Days archived", value: "\(snapshots.count)")
                    LabeledContent("Watchlist items", value: "\(watchlist.count)")

                    Button(role: .destructive) {
                        showEraseConfirm = true
                    } label: {
                        Label("Erase All Data", systemImage: "trash")
                            .foregroundStyle(Theme.alert)
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("All data is stored on-device in SwiftData and accumulates permanently until you erase it.")
                }

                // MARK: Appearance
                Section {
                    LabeledContent("Theme", value: "Dark (Intelligence)")
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("OTC Pulse is designed dark-first. Additional themes may ship later.")
                }

                // MARK: About
                Section("About") {
                    LabeledContent("App", value: "OTC Pulse")
                    LabeledContent("Version", value: "1.0 (1)")
                    LabeledContent("Coverage", value: "\(RegulatorCatalog.all.count) regulators · 5 regions")
                    Text("Offline-first intelligence on OTC derivatives regulation. A daily 24-hour feed is merged into a permanent on-device archive — everything stays searchable with no connection.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Erase the entire archive? This removes every publication, snapshot and watchlist item from this device.",
            isPresented: $showEraseConfirm,
            titleVisibility: .visible
        ) {
            Button("Erase Everything", role: .destructive) {
                dataService.eraseAllData()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
