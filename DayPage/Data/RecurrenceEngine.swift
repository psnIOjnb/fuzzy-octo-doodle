//
//  RecurrenceEngine.swift
//  DayPage
//
//  Repeating items are materialised, not computed: the item the user created
//  becomes the "series master" and real `AgendaItem` rows are written ahead
//  of it up to a rolling horizon. That keeps every screen a plain SwiftData
//  query, and lets a single occurrence be ticked, edited or deleted without
//  disturbing the rest of the series.
//

import Foundation
import SwiftData

@MainActor
enum RecurrenceEngine {

    /// How far ahead occurrences are written. Topped up on every launch.
    static let horizonDays = 120

    /// Safety valve so a pathological rule can never spin forever.
    private static let maxOccurrences = 500

    // MARK: Materialisation

    /// Tops up every series in the store. Cheap enough to run at launch.
    static func materializeAll(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let descriptor = FetchDescriptor<AgendaItem>(predicate: #Predicate<AgendaItem> { $0.isSeriesMaster })
        guard let masters = try? context.fetch(descriptor) else { return }
        for master in masters {
            materialize(master, in: context, now: now, calendar: calendar)
        }
        try? context.save()
    }

    /// Writes any missing occurrences of one series up to the horizon.
    static func materialize(_ master: AgendaItem, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard master.recurrence.repeats, let seriesID = master.seriesID else { return }

        let today = calendar.startOfDay(for: now)
        let horizon = calendar.date(byAdding: .day, value: horizonDays, to: today) ?? today

        let existing = occurrences(ofSeries: seriesID, in: context)
        var takenKeys = Set(existing.map(\.dayKey))
        let exceptions = Set(master.exceptionKeys)

        for date in dates(for: master.recurrence, from: master.day, until: horizon, calendar: calendar) {
            let key = DayKey.key(for: date, calendar: calendar)
            // Never backfill the past, never resurrect a deleted occurrence.
            if date < today || takenKeys.contains(key) || exceptions.contains(key) { continue }

            let clone = AgendaItem(
                title: master.title,
                kind: master.kind,
                day: date,
                time: master.time.map { RecurrenceEngine.time(on: date, likeThatOf: $0, calendar: calendar) },
                isAllDay: master.isAllDay,
                notes: master.notes,
                recurrence: master.recurrence,
                colorIndex: master.colorIndex,
                seriesID: seriesID,
                isSeriesMaster: false,
                createdAt: master.createdAt
            )
            context.insert(clone)
            takenKeys.insert(key)
        }
    }

    /// Turns a freshly created item into a series master and expands it.
    static func startSeries(for item: AgendaItem, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard item.recurrence.repeats else { return }
        if item.seriesID == nil {
            item.seriesID = item.id
            item.isSeriesMaster = true
        }
        materialize(item, in: context, now: now, calendar: calendar)
    }

    // MARK: Editing

    /// Applies the master's current fields to every future, untouched
    /// occurrence. Completed occurrences and past days are left alone.
    static func propagate(from master: AgendaItem, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard let seriesID = master.seriesID else { return }
        let today = calendar.startOfDay(for: now)

        for item in occurrences(ofSeries: seriesID, in: context) where item.id != master.id {
            guard item.day >= today, !item.isCompleted else { continue }
            item.title = master.title
            item.notes = master.notes
            item.kindRaw = master.kindRaw
            item.recurrenceRaw = master.recurrenceRaw
            item.colorIndex = master.colorIndex
            item.isAllDay = master.isAllDay
            item.time = master.time.map { time(on: item.day, likeThatOf: $0, calendar: calendar) }
        }
    }

    /// Rewrites a series after its rule changed: future occurrences are
    /// cleared out and regenerated from the master.
    static func rebuild(_ master: AgendaItem, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        guard let seriesID = master.seriesID else { return }
        let today = calendar.startOfDay(for: now)

        for item in occurrences(ofSeries: seriesID, in: context)
        where item.id != master.id && item.day >= today {
            context.delete(item)
        }

        if master.recurrence.repeats {
            master.isSeriesMaster = true
            materialize(master, in: context, now: now, calendar: calendar)
        } else {
            master.isSeriesMaster = false
            master.seriesID = nil
            master.exceptionKeys = []
        }
    }

    // MARK: Deleting

    /// Removes one day out of a series and remembers not to re-create it.
    static func deleteOccurrence(_ item: AgendaItem, in context: ModelContext) {
        if let seriesID = item.seriesID, let master = master(ofSeries: seriesID, in: context) {
            if master.id == item.id {
                // Deleting the master: promote the next occurrence so the
                // rule (and its exception list) survives.
                let survivors = occurrences(ofSeries: seriesID, in: context)
                    .filter { $0.id != item.id }
                    .sorted { $0.day < $1.day }
                if let heir = survivors.first {
                    heir.isSeriesMaster = true
                    heir.recurrenceRaw = master.recurrenceRaw
                    heir.exceptionKeys = master.exceptionKeys + [item.dayKey]
                }
            } else {
                master.exceptionKeys.append(item.dayKey)
            }
        }
        context.delete(item)
    }

    /// Removes the whole series, past occurrences included.
    static func deleteSeries(_ item: AgendaItem, in context: ModelContext) {
        guard let seriesID = item.seriesID else {
            context.delete(item)
            return
        }
        for member in occurrences(ofSeries: seriesID, in: context) {
            context.delete(member)
        }
    }

    // MARK: Queries

    static func occurrences(ofSeries seriesID: UUID, in context: ModelContext) -> [AgendaItem] {
        let target: UUID? = seriesID
        let descriptor = FetchDescriptor<AgendaItem>(predicate: #Predicate<AgendaItem> { $0.seriesID == target })
        return (try? context.fetch(descriptor)) ?? []
    }

    static func master(ofSeries seriesID: UUID, in context: ModelContext) -> AgendaItem? {
        occurrences(ofSeries: seriesID, in: context).first { $0.isSeriesMaster }
    }

    // MARK: Date maths

    /// Every occurrence date of `rule` in `[start, end]`, `start` included.
    static func dates(for rule: Recurrence, from start: Date, until end: Date, calendar: Calendar = .current) -> [Date] {
        guard rule.repeats else { return [calendar.startOfDay(for: start)] }

        let first = calendar.startOfDay(for: start)
        guard first <= end else { return [] }

        var result: [Date] = []
        var step = 0
        var cursor = first

        while cursor <= end && result.count < maxOccurrences {
            if rule != .weekdays || isWeekday(cursor, calendar: calendar) {
                result.append(cursor)
            }
            step += 1
            guard let next = advance(first, by: step, rule: rule, calendar: calendar) else { break }
            // A rule that stops moving forward would loop forever.
            guard next > cursor else { break }
            cursor = next
        }
        return result
    }

    private static func advance(_ start: Date, by step: Int, rule: Recurrence, calendar: Calendar) -> Date? {
        switch rule {
        case .none: nil
        case .daily, .weekdays: calendar.date(byAdding: .day, value: step, to: start)
        case .weekly: calendar.date(byAdding: .day, value: 7 * step, to: start)
        case .biweekly: calendar.date(byAdding: .day, value: 14 * step, to: start)
        case .monthly: calendar.date(byAdding: .month, value: step, to: start)
        case .yearly: calendar.date(byAdding: .year, value: step, to: start)
        }
    }

    private static func isWeekday(_ date: Date, calendar: Calendar) -> Bool {
        !calendar.isDateInWeekend(date)
    }

    /// Places `template`'s hour and minute onto `day`. Pure arithmetic, so
    /// value types off the main actor can use it too.
    nonisolated static func time(on day: Date, likeThatOf template: Date, calendar: Calendar = .current) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: template)
        var merged = DateComponents()
        merged.year = dayParts.year
        merged.month = dayParts.month
        merged.day = dayParts.day
        merged.hour = timeParts.hour
        merged.minute = timeParts.minute
        return calendar.date(from: merged) ?? day
    }
}
