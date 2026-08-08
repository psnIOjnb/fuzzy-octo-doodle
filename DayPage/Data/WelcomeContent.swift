//
//  WelcomeContent.swift
//  DayPage
//
//  A first-launch page so the app opens with something on it. Written once
//  and never again; Settings can erase it or put it back.
//

import Foundation
import SwiftData

@MainActor
enum WelcomeContent {

    static func seed(into context: ModelContext, on day: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: day)

        let items: [AgendaItem] = [
            AgendaItem(
                title: "Tick me off — that's a reminder",
                kind: .reminder,
                day: today,
                colorIndex: 0
            ),
            AgendaItem(
                title: "Everything stays on this device",
                kind: .event,
                day: today,
                isAllDay: true,
                notes: "No account, no sync, no network calls. Export from Settings whenever you want a copy.",
                colorIndex: 3
            ),
            AgendaItem(
                title: "Quick add reads plain English",
                kind: .event,
                day: today,
                time: RecurrenceEngine.time(on: today, likeThatOf: at(9, 0, on: today, calendar: calendar), calendar: calendar),
                notes: "Tap + and try: \"Coffee with Sam tomorrow at 9:30\" or \"Standup every weekday 9am\".",
                colorIndex: 2
            ),
            AgendaItem(
                title: "Write today's note below",
                kind: .reminder,
                day: today,
                time: RecurrenceEngine.time(on: today, likeThatOf: at(21, 0, on: today, calendar: calendar), calendar: calendar),
                colorIndex: 4
            ),
        ]

        for item in items { context.insert(item) }

        let note = DailyNote(day: today, text: """
        # Welcome to DayPage

        Events, reminders and a daily note on **one page**, one day at a time.

        - The **Agenda** card splits into untimed items on the left and timed \
        ones on the right.
        - Unfinished reminders roll forward and show up as *Overdue* until \
        you deal with them.
        - This note takes Markdown. Tap the **A** button to switch between \
        writing and reading.

        Swipe the date, or use the calendar button, to move between days.
        """)
        context.insert(note)

        try? context.save()
    }

    private static func at(_ hour: Int, _ minute: Int, on day: Date, calendar: Calendar) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        return calendar.date(from: parts) ?? day
    }

    /// Deletes every item and note in the store.
    static func eraseAll(from context: ModelContext) {
        try? context.delete(model: AgendaItem.self)
        try? context.delete(model: DailyNote.self)
        try? context.save()
    }
}
