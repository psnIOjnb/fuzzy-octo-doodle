//
//  AgendaCard.swift
//  DayPage
//
//  The day's events and reminders in two columns: untimed on the left
//  (all-day events, loose reminders, anything overdue), timed on the right.
//  Collapsing the card leaves a one-line summary behind.
//

import SwiftUI
import SwiftData

@MainActor
struct AgendaCard: View {

    let items: [AgendaItem]
    let overdue: [AgendaItem]
    let onAdd: () -> Void
    let onEdit: (AgendaItem) -> Void

    @Environment(DayStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    /// Series member awaiting a "this one or all of them?" answer.
    @State private var deleteTarget: AgendaItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(symbol: "calendar.badge.clock", title: "Agenda") {
                IconButton(
                    systemName: store.isAgendaCollapsed
                        ? "arrow.up.and.line.horizontal.and.arrow.down"
                        : "arrow.down.and.line.horizontal.and.arrow.up",
                    accessibilityLabel: store.isAgendaCollapsed ? "Expand agenda" : "Collapse agenda"
                ) {
                    withAnimation(.snappy(duration: 0.2)) { store.isAgendaCollapsed.toggle() }
                }

                IconButton(systemName: "plus", accessibilityLabel: "Add item", filled: true, action: onAdd)
            }

            if store.isAgendaCollapsed {
                Text(summary)
                    .font(Theme.rowSubtitle)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                columns
            }
        }
        .card()
        .confirmationDialog(
            "This is a repeating item",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete this occurrence", role: .destructive) {
                if let target = deleteTarget { delete(target, wholeSeries: false) }
                deleteTarget = nil
            }
            Button("Delete all occurrences", role: .destructive) {
                if let target = deleteTarget { delete(target, wholeSeries: true) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
    }

    // MARK: Columns

    private var columns: some View {
        HStack(alignment: .top, spacing: 0) {
            column(caption: "ALL DAY + NO TIME", rows: untimedRows, empty: "Nothing untimed")
                .padding(.trailing, 12)

            Rectangle()
                .fill(Theme.stroke)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            column(caption: "TIMED", rows: timedRows, empty: "Nothing scheduled")
                .padding(.leading, 12)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func column(caption: String, rows: [AgendaItem], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ColumnCaption(text: caption)

            if rows.isEmpty {
                EmptyLine(text: empty)
            } else {
                ForEach(rows) { item in
                    AgendaRow(
                        item: item,
                        onToggle: { toggle(item) },
                        onEdit: { onEdit(item) },
                        onMoveToTomorrow: { move(item, byDays: 1) },
                        onDelete: { requestDelete(item) }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Row sets

    private var visibleItems: [AgendaItem] {
        settings.showCompleted ? items : items.filter { !$0.isCompleted }
    }

    /// Overdue reminders lead the left column, oldest first.
    private var untimedRows: [AgendaItem] {
        let carried = overdue.sorted { $0.day < $1.day }
        let own = visibleItems.filter { !$0.isTimed }.sorted { $0.sortKey < $1.sortKey }
        return carried + own
    }

    private var timedRows: [AgendaItem] {
        visibleItems.filter(\.isTimed).sorted { $0.sortKey < $1.sortKey }
    }

    private var summary: String {
        let all = untimedRows + timedRows
        guard !all.isEmpty else { return "Nothing on this day" }

        var parts: [String] = []
        let events = all.filter { $0.kind == .event }.count
        let openReminders = all.filter { $0.kind == .reminder && !$0.isCompleted }.count
        let overdueCount = overdue.count

        if events > 0 { parts.append("\(events) event\(events == 1 ? "" : "s")") }
        if openReminders > 0 { parts.append("\(openReminders) to do") }
        if overdueCount > 0 { parts.append("\(overdueCount) overdue") }
        if parts.isEmpty { parts.append("all done") }
        return parts.joined(separator: " · ")
    }

    // MARK: Actions

    private func toggle(_ item: AgendaItem) {
        withAnimation(.snappy(duration: 0.18)) { item.toggleCompletion() }
        if item.isCompleted {
            NotificationScheduler.cancel(itemID: item.id)
        }
        save()
    }

    private func move(_ item: AgendaItem, byDays days: Int) {
        let calendar = Calendar.current
        guard let newDay = calendar.date(byAdding: .day, value: days, to: item.day) else { return }
        item.day = calendar.startOfDay(for: newDay)
        if let time = item.time {
            item.time = RecurrenceEngine.time(on: item.day, likeThatOf: time)
        }
        // A moved occurrence leaves its series behind.
        if item.seriesID != nil, !item.isSeriesMaster {
            item.seriesID = nil
            item.recurrenceRaw = Recurrence.none.rawValue
        }
        save()
    }

    private func requestDelete(_ item: AgendaItem) {
        if item.seriesID != nil {
            deleteTarget = item
        } else {
            delete(item, wholeSeries: false)
        }
    }

    private func delete(_ item: AgendaItem, wholeSeries: Bool) {
        NotificationScheduler.cancel(itemID: item.id)
        if wholeSeries {
            RecurrenceEngine.deleteSeries(item, in: context)
        } else {
            RecurrenceEngine.deleteOccurrence(item, in: context)
        }
        save()
    }

    private func save() {
        try? context.save()
        Task { await NotificationScheduler.refresh(context: context, settings: settings) }
    }
}
