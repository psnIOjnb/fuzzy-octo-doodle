//
//  AgendaItem.swift
//  DayPage
//
//  The single row type behind the agenda: an event (something that happens
//  at a time) or a reminder (something you tick off). Both live on one day,
//  which is what lets the whole app be organised around "the page for today".
//
//  Enums are persisted as raw strings so `#Predicate` can filter on them —
//  SwiftData predicates can only reach stored, primitive properties.
//

import Foundation
import SwiftData

// MARK: - Kind

enum ItemKind: String, CaseIterable, Identifiable, Codable {
    case event
    case reminder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .event: "Event"
        case .reminder: "Reminder"
        }
    }
}

// MARK: - Recurrence

enum Recurrence: String, CaseIterable, Identifiable, Codable {
    case none
    case daily
    case weekdays
    case weekly
    case biweekly
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Never"
        case .daily: "Every day"
        case .weekdays: "Every weekday"
        case .weekly: "Every week"
        case .biweekly: "Every 2 weeks"
        case .monthly: "Every month"
        case .yearly: "Every year"
        }
    }

    /// Compact label for the row badge.
    var shortLabel: String {
        switch self {
        case .none: ""
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekly: "Weekly"
        case .biweekly: "Fortnightly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    var repeats: Bool { self != .none }
}

// MARK: - Model

@Model
final class AgendaItem {

    @Attribute(.unique) var id: UUID

    var title: String
    var notes: String

    /// Midnight of the day this item belongs to — the key the agenda queries on.
    var day: Date

    /// Full date-time of the item, or `nil` when it has no specific time
    /// (all-day events and undated reminders share the left-hand column).
    var time: Date?

    /// All-day events are labelled as such; reminders never are.
    var isAllDay: Bool

    var kindRaw: String
    var recurrenceRaw: String

    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    /// Index into `Theme.itemColors`, used for the event accent bar.
    var colorIndex: Int

    // MARK: Series

    /// Shared by every occurrence of a repeating item (`nil` for one-offs).
    var seriesID: UUID?

    /// True for the item that owns the recurrence rule. Occurrences generated
    /// from it are plain items that carry the same `seriesID`.
    var isSeriesMaster: Bool

    /// Day keys ("2026-06-28") the user deleted out of the series, so the
    /// engine does not helpfully re-create them on the next materialisation.
    var exceptionKeys: [String]

    init(
        title: String,
        kind: ItemKind = .event,
        day: Date,
        time: Date? = nil,
        isAllDay: Bool = false,
        notes: String = "",
        recurrence: Recurrence = .none,
        colorIndex: Int = 0,
        seriesID: UUID? = nil,
        isSeriesMaster: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.day = Calendar.current.startOfDay(for: day)
        self.time = time
        self.isAllDay = isAllDay
        self.kindRaw = kind.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.isCompleted = false
        self.completedAt = nil
        self.createdAt = createdAt
        self.colorIndex = colorIndex
        self.seriesID = seriesID
        self.isSeriesMaster = isSeriesMaster
        self.exceptionKeys = []
    }

    // MARK: Derived

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRaw) ?? .event }
        set { kindRaw = newValue.rawValue }
    }

    var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var dayKey: String { DayKey.key(for: day) }

    /// Items with a time go in the right-hand "TIMED" column, everything
    /// else (all-day events, loose reminders) in the left-hand column.
    var isTimed: Bool { time != nil && !isAllDay }

    /// Ordering within a column: timed items by clock, the rest by entry order.
    var sortKey: Date { time ?? createdAt }

    /// An unfinished reminder from a previous day still needs doing.
    func isOverdue(asOf reference: Date = .now) -> Bool {
        guard kind == .reminder, !isCompleted else { return false }
        return day < Calendar.current.startOfDay(for: reference)
    }

    /// The moment a notification should fire for this item, if any.
    func alertDate(leadMinutes: Int) -> Date? {
        guard let time, !isCompleted else { return nil }
        return time.addingTimeInterval(TimeInterval(-leadMinutes * 60))
    }

    func toggleCompletion() {
        isCompleted.toggle()
        completedAt = isCompleted ? .now : nil
    }
}

// MARK: - Day keys

/// Stable "yyyy-MM-dd" identifiers built from calendar components, so no
/// `DateFormatter` (and no main-actor isolation) is needed to make one.
enum DayKey {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
