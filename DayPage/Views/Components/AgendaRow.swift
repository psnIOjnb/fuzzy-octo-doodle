//
//  AgendaRow.swift
//  DayPage
//
//  One line of the agenda. Reminders lead with a tappable checkbox, events
//  with a clock; the subtitle carries the time, the repeat rule and the
//  overdue flag.
//

import SwiftUI

@MainActor
struct AgendaRow: View {

    let item: AgendaItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onMoveToTomorrow: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            marker

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.rowTitle)
                    .foregroundStyle(item.isCompleted ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(item.isCompleted, color: Theme.textTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.rowSubtitle)
                        .foregroundStyle(item.isOverdue() ? Theme.overdue : Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }

            if item.kind == .reminder {
                Button(action: onToggle) {
                    Label(
                        item.isCompleted ? "Mark as not done" : "Mark as done",
                        systemImage: item.isCompleted ? "arrow.uturn.backward" : "checkmark"
                    )
                }
            }

            Button(action: onMoveToTomorrow) {
                Label("Move to next day", systemImage: "arrow.right.circle")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Marker

    @ViewBuilder
    private var marker: some View {
        switch item.kind {
        case .reminder:
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: item.isCompleted ? .semibold : .regular))
                    .foregroundStyle(item.isCompleted ? Theme.done : markerTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isCompleted ? "Mark as not done" : "Mark as done")

        case .event:
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(markerTint)
                .padding(.top, 1)
        }
    }

    private var markerTint: Color {
        item.isOverdue() ? Theme.overdue : Theme.itemColor(item.colorIndex).opacity(0.9)
    }

    // MARK: Subtitle

    private var subtitle: String? {
        var parts: [String] = []

        if item.isOverdue() {
            parts.append("Overdue")
            if item.time != nil || item.isAllDay {
                parts.append(Formatters.mediumDate.string(from: item.day))
            }
        } else if item.isAllDay {
            parts.append("All day")
        } else if let time = item.time {
            parts.append(Formatters.time.string(from: time))
        }

        if item.recurrence.repeats { parts.append(item.recurrence.shortLabel) }
        if !item.notes.isEmpty { parts.append("note") }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        var text = "\(item.kind.label): \(item.title)"
        if let subtitle { text += ", \(subtitle)" }
        if item.isCompleted { text += ", done" }
        return text
    }
}
