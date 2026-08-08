//
//  DayHeaderBar.swift
//  DayPage
//
//  Calendar button, the three-day picker, settings button. The picker always
//  shows the selected day flanked by its neighbours, so the same control
//  reads as "Yesterday · Today · Tomorrow" near today and as real dates
//  further out.
//

import SwiftUI

@MainActor
struct DayHeaderBar: View {

    let onCalendar: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            IconButton(systemName: "calendar", accessibilityLabel: "Open calendar", action: onCalendar)

            DayPicker()
                .frame(maxWidth: .infinity)

            IconButton(systemName: "gearshape", accessibilityLabel: "Open settings", action: onSettings)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 10)
    }
}

// MARK: - Three-day picker

@MainActor
private struct DayPicker: View {

    @Environment(DayStore.self) private var store

    var body: some View {
        HStack(spacing: 2) {
            segment(for: store.previousDay, isSelected: false)
            segment(for: store.selectedDay, isSelected: true)
            segment(for: store.nextDay, isSelected: false)
        }
        .padding(3)
        .background(Theme.inset, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }

    private func segment(for date: Date, isSelected: Bool) -> some View {
        Button {
            if isSelected {
                // Tapping the middle segment when it is not today jumps home.
                store.goToToday()
            } else {
                store.select(date)
            }
        } label: {
            Text(store.segmentLabel(for: date))
                .font(.footnote.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(isSelected ? Theme.accent.opacity(0.22) : .clear)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Formatters.mediumDate.string(from: date)))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
