//
//  DayStore.swift
//  DayPage
//
//  Navigation state (which day is on screen) plus the small pile of calendar
//  arithmetic every view needs. Persistence itself stays in SwiftData —
//  this object never owns model objects.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class DayStore {

    /// Midnight of the day currently on screen.
    private(set) var selectedDay: Date

    /// Collapsed state of the agenda card, shared across day changes.
    var isAgendaCollapsed: Bool

    private let calendar: Calendar

    init(calendar: Calendar = .current, startsCollapsed: Bool = false) {
        self.calendar = calendar
        self.selectedDay = calendar.startOfDay(for: .now)
        self.isAgendaCollapsed = startsCollapsed
    }

    // MARK: Navigation

    var isToday: Bool { calendar.isDateInToday(selectedDay) }

    var previousDay: Date { calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay }
    var nextDay: Date { calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay }

    func select(_ date: Date) {
        let target = calendar.startOfDay(for: date)
        guard target != selectedDay else { return }
        selectedDay = target
    }

    func goToPreviousDay() { select(previousDay) }
    func goToNextDay() { select(nextDay) }

    func goToToday() {
        select(.now)
    }

    /// Called on foreground: if the app sat overnight on "today", move with it.
    func refreshForNewDayIfNeeded(wasShowingToday: Bool) {
        guard wasShowingToday else { return }
        selectedDay = calendar.startOfDay(for: .now)
    }

    // MARK: Labels

    /// "Sunday, 28 June" — the page headline. The year is added whenever the
    /// day falls outside the current one, so old pages are never ambiguous.
    func headline(for date: Date) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: .now)
        return sameYear
            ? Formatters.headline.string(from: date)
            : Formatters.headlineWithYear.string(from: date)
    }

    /// Segment captions: relative words near today, a short date further out.
    func segmentLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return Formatters.segment.string(from: date)
    }

    // MARK: Ranges

    func monthBounds(for date: Date) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return (start, end)
    }
}

// MARK: - Shared formatters

/// `DateFormatter` is not Sendable, so the shared instances are pinned to the
/// main actor — every caller (views, exporters) already runs there.
@MainActor
enum Formatters {
    static let headline: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f
    }()

    static let headlineWithYear: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        return f
    }()

    static let segment: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEd")
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return f
    }()

    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let exportDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
