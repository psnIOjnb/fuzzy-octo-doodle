//
//  NotificationManager.swift
//  OTC Pulse
//
//  Local notifications for newly-ingested high-impact publications.
//  Nothing leaves the device — alerts are scheduled locally right after
//  a merge detects fresh items scoring >= 7.5.
//

import Foundation
import UserNotifications

@MainActor
enum NotificationManager {

    /// Ask the user for permission. Returns whether alerts are authorized.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Fire a local alert summarizing freshly ingested high-impact items.
    static func notifyHighImpact(items: [String]) {
        guard !items.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = items.count == 1
            ? "High-impact publication"
            : "\(items.count) high-impact publications"
        // Show up to two titles, then summarize the rest.
        var body = items.prefix(2).joined(separator: "\n")
        if items.count > 2 { body += "\n+\(items.count - 2) more" }
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "high-impact-\(UUID().uuidString)",
            content: content,
            // Small delay so the alert lands after the refresh UI settles.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
}
