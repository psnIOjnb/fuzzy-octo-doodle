//
//  CalendarSheet.swift
//  DayPage
//
//  Month grid for jumping between days, with a dot under every day that has
//  something on it, plus full-text search across every item and note in the
//  store. Both run against the local database, so search works on a plane.
//

import SwiftUI
import SwiftData

private struct CalendarDayMark {
    var itemCount = 0
    var hasOverdue = false
    var hasNote = false
}

private struct CalendarSearchHit: Identifiable {
    let id: String
    let day: Date
    let title: String
    let snippet: String?
    let symbol: String
}

@MainActor
struct CalendarSheet: View {

    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(DayStore.self) private var store

    @State private var month: Date = Calendar.current.startOfDay(for: .now)
    @State private var query = ""
    @State private var marks: [String: CalendarDayMark] = [:]
    @State private var results: [CalendarSearchHit] = []

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    monthView
                } else {
                    searchResults
                }
            }
            .background(Theme.background)
            .navigationTitle(query.isEmpty ? "Calendar" : "Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Today") { pick(Date.now) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search items and notes")
        }
        .onAppear {
            month = calendar.startOfDay(for: store.selectedDay)
        }
        .task(id: month) { await loadMarks() }
        .task(id: query) { await runSearch() }
    }

    // MARK: Month grid

    private var monthView: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                    // Indexed, because weekday initials repeat (S M T W T F S).
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            dayCell(date)
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }

                legend
            }
            .padding(Theme.pagePadding)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(Formatters.monthYear.string(from: month))
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(Theme.textPrimary)

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .accessibilityLabel("Next month")
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DayKey.key(for: date, calendar: calendar)
        let mark = marks[key]
        let isSelected = calendar.isDate(date, inSameDayAs: store.selectedDay)
        let isToday = calendar.isDateInToday(date)

        return Button {
            pick(date)
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.accent : Theme.textPrimary))
                    .frame(width: 32, height: 32)
                    .background {
                        Circle().fill(isSelected ? Theme.accent : .clear)
                    }

                HStack(spacing: 3) {
                    if let mark, mark.itemCount > 0 {
                        Circle()
                            .fill(mark.hasOverdue ? Theme.overdue : Theme.accent)
                            .frame(width: 5, height: 5)
                    }
                    if mark?.hasNote == true {
                        Circle()
                            .fill(Theme.textTertiary)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: date, mark: mark))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text("Agenda")
            }
            HStack(spacing: 5) {
                Circle().fill(Theme.textTertiary).frame(width: 5, height: 5)
                Text("Note")
            }
            HStack(spacing: 5) {
                Circle().fill(Theme.overdue).frame(width: 5, height: 5)
                Text("Overdue")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Search

    @ViewBuilder
    private var searchResults: some View {
        if results.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(Theme.textTertiary)
                Text("Nothing matches \"\(query)\"")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(results) { hit in
                Button {
                    pick(hit.day)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: hit.symbol)
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                            Text(Formatters.mediumDate.string(from: hit.day))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Text(hit.title)
                            .font(Theme.rowTitle)
                            .foregroundStyle(Theme.textPrimary)
                        if let snippet = hit.snippet {
                            Text(snippet)
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    // MARK: Data

    private func loadMarks() async {
        let (start, end) = store.monthBounds(for: month)
        let today = calendar.startOfDay(for: .now)

        let items = (try? context.fetch(FetchDescriptor<AgendaItem>(
            predicate: #Predicate<AgendaItem> { $0.day >= start && $0.day < end }
        ))) ?? []
        let notes = (try? context.fetch(FetchDescriptor<DailyNote>(
            predicate: #Predicate<DailyNote> { $0.day >= start && $0.day < end }
        ))) ?? []

        var next: [String: CalendarDayMark] = [:]
        for item in items {
            var mark = next[item.dayKey] ?? CalendarDayMark()
            mark.itemCount += 1
            if item.kind == .reminder, !item.isCompleted, item.day < today { mark.hasOverdue = true }
            next[item.dayKey] = mark
        }
        for note in notes where !note.isEmpty {
            var mark = next[note.dayKey] ?? CalendarDayMark()
            mark.hasNote = true
            next[note.dayKey] = mark
        }
        marks = next
    }

    private func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = []
            return
        }
        // Small debounce so typing doesn't hit the store on every keystroke.
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        let itemDescriptor = FetchDescriptor<AgendaItem>(
            predicate: #Predicate<AgendaItem> {
                $0.title.localizedStandardContains(text) || $0.notes.localizedStandardContains(text)
            },
            sortBy: [SortDescriptor(\AgendaItem.day, order: .reverse)]
        )
        let noteDescriptor = FetchDescriptor<DailyNote>(
            predicate: #Predicate<DailyNote> { $0.text.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\DailyNote.day, order: .reverse)]
        )

        let items = (try? context.fetch(itemDescriptor)) ?? []
        let notes = (try? context.fetch(noteDescriptor)) ?? []

        var hits = items.map { item in
            CalendarSearchHit(
                id: "item-\(item.id.uuidString)",
                day: item.day,
                title: item.title,
                snippet: item.notes.isEmpty ? nil : item.notes,
                symbol: item.kind == .reminder ? "checkmark.circle" : "clock"
            )
        }
        hits += notes.map { note in
            CalendarSearchHit(
                id: "note-\(note.dayKey)",
                day: note.day,
                title: "Daily note",
                snippet: Self.snippet(of: note.text, around: text),
                symbol: "square.and.pencil"
            )
        }

        results = hits.sorted { $0.day > $1.day }
    }

    /// The line the match sits on, trimmed to something list-sized.
    private static func snippet(of body: String, around needle: String) -> String {
        let line = body
            .components(separatedBy: .newlines)
            .first { $0.localizedCaseInsensitiveContains(needle) } ?? body
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.count > 140 ? String(trimmed.prefix(140)) + "…" : trimmed
    }

    // MARK: Layout helpers

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    private var gridDays: [Date?] {
        let (start, end) = store.monthBounds(for: month)
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day ?? 30
        let weekdayOfFirst = calendar.component(.weekday, from: start)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: start))
        }
        return cells
    }

    private func accessibilityLabel(for date: Date, mark: CalendarDayMark?) -> String {
        var text = Formatters.mediumDate.string(from: date)
        if let mark {
            if mark.itemCount > 0 { text += ", \(mark.itemCount) item\(mark.itemCount == 1 ? "" : "s")" }
            if mark.hasNote { text += ", has a note" }
            if mark.hasOverdue { text += ", has overdue reminders" }
        }
        return text
    }

    // MARK: Actions

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.snappy(duration: 0.2)) { month = next }
    }

    private func pick(_ date: Date) {
        onPick(calendar.startOfDay(for: date))
        dismiss()
    }
}
