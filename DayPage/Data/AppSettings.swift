//
//  AppSettings.swift
//  DayPage
//
//  UserDefaults-backed preferences, exposed as an @Observable object so both
//  views and the notification scheduler read the same values.
//
//  Each setting is a computed property over UserDefaults; observation rides
//  on a single `revision` counter that every setter bumps. That keeps the
//  defaults store as the one source of truth instead of shadowing it.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppSettings {

    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let leadMinutes = "reminderLeadMinutes"
        static let showCompleted = "showCompleted"
        static let agendaCollapsed = "agendaStartsCollapsed"
        static let noteReminderEnabled = "dailyNoteReminderEnabled"
        static let noteReminderHour = "dailyNoteReminderHour"
        static let rollOverdue = "rollOverdueReminders"
        static let renderMarkdown = "renderMarkdown"
        static let hasSeeded = "hasSeededWelcomeContent"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Bumped by every setter; read by every getter. This is what SwiftUI
    /// actually tracks.
    private var revision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.notificationsEnabled: false,
            Key.leadMinutes: 10,
            Key.showCompleted: true,
            Key.agendaCollapsed: false,
            Key.noteReminderEnabled: false,
            Key.noteReminderHour: 21,
            Key.rollOverdue: true,
            Key.renderMarkdown: false,
            Key.hasSeeded: false,
        ])
    }

    // MARK: Settings

    /// Fire local alerts for timed events and reminders.
    var notificationsEnabled: Bool {
        get { flag(Key.notificationsEnabled) }
        set { set(newValue, Key.notificationsEnabled) }
    }

    /// How many minutes before the item its alert fires.
    var leadMinutes: Int {
        get { number(Key.leadMinutes) }
        set { set(newValue, Key.leadMinutes) }
    }

    /// Keep ticked items visible (struck through) instead of hiding them.
    var showCompleted: Bool {
        get { flag(Key.showCompleted) }
        set { set(newValue, Key.showCompleted) }
    }

    /// Open each day with the agenda card collapsed to a one-line summary.
    var agendaStartsCollapsed: Bool {
        get { flag(Key.agendaCollapsed) }
        set { set(newValue, Key.agendaCollapsed) }
    }

    /// Nightly nudge to write the daily note.
    var noteReminderEnabled: Bool {
        get { flag(Key.noteReminderEnabled) }
        set { set(newValue, Key.noteReminderEnabled) }
    }

    /// Hour of day (0–23) for the note nudge.
    var noteReminderHour: Int {
        get { number(Key.noteReminderHour) }
        set { set(newValue, Key.noteReminderHour) }
    }

    /// Show unfinished reminders from earlier days on today's page.
    var rollOverdueReminders: Bool {
        get { flag(Key.rollOverdue) }
        set { set(newValue, Key.rollOverdue) }
    }

    /// Daily note renders Markdown instead of showing raw text.
    var renderMarkdown: Bool {
        get { flag(Key.renderMarkdown) }
        set { set(newValue, Key.renderMarkdown) }
    }

    /// First-launch welcome content has been written (or deliberately erased).
    var hasSeededWelcomeContent: Bool {
        get { flag(Key.hasSeeded) }
        set { set(newValue, Key.hasSeeded) }
    }

    // MARK: Storage

    private func flag(_ key: String) -> Bool {
        trackReads()
        return defaults.bool(forKey: key)
    }

    private func number(_ key: String) -> Int {
        trackReads()
        return defaults.integer(forKey: key)
    }

    private func set(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
        revision &+= 1
    }

    private func set(_ value: Int, _ key: String) {
        defaults.set(value, forKey: key)
        revision &+= 1
    }

    /// Touching `revision` is what registers the dependency with Observation.
    private func trackReads() {
        _ = revision
    }

    // MARK: Choices

    static let leadMinuteOptions = [0, 5, 10, 15, 30, 60]

    static func leadLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: "At the time"
        case 60: "1 hour before"
        default: "\(minutes) min before"
        }
    }
}
