//
//  NotificationScheduler.swift
//  DayPage
//
//  Local notifications only — UNUserNotificationCenter delivers everything
//  from the device itself, so alerts keep working in airplane mode.
//
//  iOS keeps at most 64 pending requests per app, so the scheduler rewrites
//  the whole queue from scratch (soonest first) whenever data changes.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationScheduler {

    private static let itemPrefix = "item-"
    private static let noteIdentifier = "daily-note-nudge"
    private static let maxPending = 60

    // MARK: Authorization

    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: Item alerts

    /// Rebuilds the pending queue from everything scheduled in the future.
    static func refresh(context: ModelContext, settings: AppSettings, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let staleItemIDs = pending.map(\.identifier).filter { $0.hasPrefix(itemPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleItemIDs)

        guard settings.notificationsEnabled else { return }

        let descriptor = FetchDescriptor<AgendaItem>(
            predicate: #Predicate<AgendaItem> { $0.time != nil && !$0.isCompleted },
            sortBy: [SortDescriptor(\AgendaItem.day)]
        )
        guard let items = try? context.fetch(descriptor) else { return }

        let upcoming = items
            .compactMap { item -> (AgendaItem, Date)? in
                guard let fire = item.alertDate(leadMinutes: settings.leadMinutes), fire > now else { return nil }
                return (item, fire)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(maxPending)

        for (item, fire) in upcoming {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = alertBody(for: item, leadMinutes: settings.leadMinutes)
            content.sound = .default

            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(
                identifier: itemPrefix + item.id.uuidString,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func alertBody(for item: AgendaItem, leadMinutes: Int) -> String {
        guard let time = item.time else { return item.kind.label }
        let clock = Formatters.time.string(from: time)
        if leadMinutes == 0 {
            return item.kind == .reminder ? "Due now — \(clock)" : "Starting now — \(clock)"
        }
        return item.kind == .reminder ? "Due at \(clock)" : "Starts at \(clock)"
    }

    /// Drops a single item's alert immediately (used when ticking it off).
    static func cancel(itemID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [itemPrefix + itemID.uuidString])
    }

    // MARK: Daily note nudge

    /// A repeating daily reminder to write the note.
    static func refreshNoteNudge(settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [noteIdentifier])
        guard settings.notificationsEnabled, settings.noteReminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily note"
        content.body = "How did today go?"
        content.sound = .default

        var parts = DateComponents()
        parts.hour = settings.noteReminderHour
        parts.minute = 0

        let request = UNNotificationRequest(
            identifier: noteIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        )
        try? await center.add(request)
    }

    /// Clears everything — used when notifications are switched off or the
    /// store is erased.
    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
