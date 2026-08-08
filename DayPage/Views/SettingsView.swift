//
//  SettingsView.swift
//  DayPage
//
//  Preferences, storage stats and export. Nothing here talks to a server —
//  "export" means handing Markdown to the system share sheet.
//

import SwiftUI
import SwiftData

@MainActor
struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query private var items: [AgendaItem]
    @Query private var notes: [DailyNote]

    @State private var exportText = ""
    @State private var showEraseConfirmation = false
    @State private var authorizationDenied = false

    var body: some View {
        NavigationStack {
            Form {
                notificationsSection
                pageSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await refreshExport() }
            .confirmationDialog(
                "Erase everything?",
                isPresented: $showEraseConfirmation,
                titleVisibility: .visible
            ) {
                Button("Erase all items and notes", role: .destructive, action: eraseEverything)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This deletes every event, reminder and daily note on this device. It cannot be undone.")
            }
        }
    }

    // MARK: Sections

    private var notificationsSection: some View {
        Section {
            Toggle("Alerts for timed items", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { newValue in
                    settings.notificationsEnabled = newValue
                    Task { await applyNotificationChange(enabled: newValue) }
                }
            ))

            if settings.notificationsEnabled {
                Picker("Alert me", selection: Binding(
                    get: { settings.leadMinutes },
                    set: { settings.leadMinutes = $0; Task { await refreshAlerts() } }
                )) {
                    ForEach(AppSettings.leadMinuteOptions, id: \.self) { minutes in
                        Text(AppSettings.leadLabel(minutes)).tag(minutes)
                    }
                }

                Toggle("Nightly daily-note nudge", isOn: Binding(
                    get: { settings.noteReminderEnabled },
                    set: { settings.noteReminderEnabled = $0; Task { await NotificationScheduler.refreshNoteNudge(settings: settings) } }
                ))

                if settings.noteReminderEnabled {
                    Picker("Nudge at", selection: Binding(
                        get: { settings.noteReminderHour },
                        set: { settings.noteReminderHour = $0; Task { await NotificationScheduler.refreshNoteNudge(settings: settings) } }
                    )) {
                        ForEach(17...23, id: \.self) { hour in
                            Text(hourLabel(hour)).tag(hour)
                        }
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text(authorizationDenied
                 ? "Notifications are turned off for DayPage in the Settings app."
                 : "Alerts are scheduled by the device itself and fire without a connection.")
        }
    }

    private var pageSection: some View {
        Section("Day page") {
            Toggle("Show completed items", isOn: Binding(
                get: { settings.showCompleted },
                set: { settings.showCompleted = $0 }
            ))
            Toggle("Roll unfinished reminders forward", isOn: Binding(
                get: { settings.rollOverdueReminders },
                set: { settings.rollOverdueReminders = $0 }
            ))
            Toggle("Open agenda collapsed", isOn: Binding(
                get: { settings.agendaStartsCollapsed },
                set: { settings.agendaStartsCollapsed = $0 }
            ))
            Toggle("Render note as Markdown", isOn: Binding(
                get: { settings.renderMarkdown },
                set: { settings.renderMarkdown = $0 }
            ))
        }
    }

    private var dataSection: some View {
        Section {
            LabeledContent("Events & reminders", value: "\(items.count)")
            LabeledContent("Daily notes", value: "\(notes.count)")
            LabeledContent("Days with content", value: "\(dayCount)")

            ShareLink(item: exportText, preview: SharePreview("DayPage export")) {
                Label("Export everything as Markdown", systemImage: "square.and.arrow.up")
            }

            Button {
                WelcomeContent.seed(into: context)
                rebuildExport()
            } label: {
                Label("Add the welcome page again", systemImage: "sparkles")
            }

            Button(role: .destructive) {
                showEraseConfirmation = true
            } label: {
                Label("Erase everything", systemImage: "trash")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Everything lives in a single database on this device. Nothing is uploaded, and there is no account.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: versionString)
            LabeledContent("Storage", value: "On-device (SwiftData)")
            LabeledContent("Network use", value: "None")
        }
    }

    // MARK: Values

    private var dayCount: Int {
        var keys = Set(items.map(\.dayKey))
        keys.formUnion(notes.filter { !$0.isEmpty }.map(\.dayKey))
        return keys.count
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func hourLabel(_ hour: Int) -> String {
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = 0
        let date = Calendar.current.date(from: parts) ?? .now
        return Formatters.time.string(from: date)
    }

    // MARK: Actions

    private func applyNotificationChange(enabled: Bool) async {
        if enabled {
            let granted = await NotificationScheduler.requestAuthorization()
            authorizationDenied = !granted
            if !granted {
                settings.notificationsEnabled = false
                return
            }
        } else {
            NotificationScheduler.cancelAll()
        }
        await refreshAlerts()
        await NotificationScheduler.refreshNoteNudge(settings: settings)
    }

    private func refreshAlerts() async {
        await NotificationScheduler.refresh(context: context, settings: settings)
    }

    private func refreshExport() async {
        rebuildExport()
    }

    private func rebuildExport() {
        exportText = DayExporter.archiveMarkdown(context: context)
    }

    private func eraseEverything() {
        WelcomeContent.eraseAll(from: context)
        NotificationScheduler.cancelAll()
        // Stay erased: the welcome page is only re-added on request.
        settings.hasSeededWelcomeContent = true
        rebuildExport()
    }
}
