//
//  DayExporter.swift
//  DayPage
//
//  Turns a day — or the whole archive — into Markdown. Handed to `ShareLink`,
//  so export goes through the system share sheet (Files, Notes, AirDrop) with
//  no network involved.
//

import Foundation
import SwiftData

@MainActor
enum DayExporter {

    // MARK: One day

    static func markdown(for day: Date, items: [AgendaItem], note: DailyNote?) -> String {
        var out = "# \(Formatters.headlineWithYear.string(from: day))\n"

        let untimed = items.filter { !$0.isTimed }.sorted { $0.sortKey < $1.sortKey }
        let timed = items.filter(\.isTimed).sorted { $0.sortKey < $1.sortKey }

        if !items.isEmpty {
            out += "\n## Agenda\n"
            for item in untimed { out += line(for: item) }
            for item in timed { out += line(for: item) }
        }

        if let note, !note.isEmpty {
            out += "\n## Daily note\n\n\(note.text)\n"
        }

        if items.isEmpty && (note?.isEmpty ?? true) {
            out += "\n_Nothing recorded._\n"
        }
        return out
    }

    private static func line(for item: AgendaItem) -> String {
        var prefix = "- "
        if item.kind == .reminder {
            prefix += item.isCompleted ? "[x] " : "[ ] "
        }

        var suffix: [String] = []
        if let time = item.time, !item.isAllDay {
            suffix.append(Formatters.time.string(from: time))
        } else if item.isAllDay {
            suffix.append("All day")
        }
        if item.recurrence.repeats { suffix.append(item.recurrence.shortLabel.lowercased()) }
        if item.isOverdue() { suffix.append("overdue") }

        let detail = suffix.isEmpty ? "" : " — \(suffix.joined(separator: ", "))"
        var out = "\(prefix)\(item.title)\(detail)\n"

        if !item.notes.isEmpty {
            for noteLine in item.notes.split(separator: "\n", omittingEmptySubsequences: false) {
                out += "    \(noteLine)\n"
            }
        }
        return out
    }

    // MARK: Whole archive

    /// Every day that has an item or a note, newest first.
    static func archiveMarkdown(context: ModelContext) -> String {
        let items = (try? context.fetch(FetchDescriptor<AgendaItem>(sortBy: [SortDescriptor(\AgendaItem.day)]))) ?? []
        let notes = (try? context.fetch(FetchDescriptor<DailyNote>(sortBy: [SortDescriptor(\DailyNote.day)]))) ?? []

        var itemsByKey: [String: [AgendaItem]] = [:]
        for item in items { itemsByKey[item.dayKey, default: []].append(item) }
        var notesByKey: [String: DailyNote] = [:]
        for note in notes { notesByKey[note.dayKey] = note }

        var days: [String: Date] = [:]
        for item in items { days[item.dayKey] = item.day }
        for note in notes { days[note.dayKey] = note.day }

        guard !days.isEmpty else { return "# DayPage\n\n_Nothing recorded yet._\n" }

        var out = "# DayPage export\n\n_\(days.count) day\(days.count == 1 ? "" : "s"), exported \(Formatters.mediumDate.string(from: .now))._\n\n---\n"
        for key in days.keys.sorted(by: >) {
            guard let day = days[key] else { continue }
            out += "\n" + markdown(for: day, items: itemsByKey[key] ?? [], note: notesByKey[key]) + "\n---\n"
        }
        return out
    }

    /// Suggested file name for a shared day, e.g. "DayPage 2026-06-28".
    static func fileName(for day: Date) -> String {
        "DayPage \(Formatters.exportDate.string(from: day))"
    }
}
