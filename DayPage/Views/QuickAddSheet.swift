//
//  QuickAddSheet.swift
//  DayPage
//
//  One field, plain English. The sheet shows what it understood — day, time,
//  repeat — before anything is saved, so the parser never silently guesses
//  wrong.
//

import SwiftUI
import SwiftData

@MainActor
struct QuickAddSheet: View {

    let day: Date
    /// Hands the half-parsed entry over to the full editor.
    let onOpenFullEditor: (ItemDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var input = ""
    @State private var kind: ItemKind = .event
    @FocusState private var isFocused: Bool

    private var parsed: ParsedEntry {
        QuickAddParser.parse(input, on: day)
    }

    private var canSave: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {

                TextField("Lunch with family at noon", text: $input, axis: .vertical)
                    .font(.title3)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)

                Picker("Kind", selection: $kind) {
                    ForEach(ItemKind.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                understoodRow

                Spacer(minLength: 0)

                Button(action: { onOpenFullEditor(draft()) }) {
                    Label("More options", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.medium))
                }
                .disabled(!canSave)
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save).disabled(!canSave)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    // MARK: Parsed summary

    private var understoodRow: some View {
        let entry = parsed
        return VStack(alignment: .leading, spacing: 8) {
            ColumnCaption(text: "WILL BE SAVED AS")

            Text(entry.title.isEmpty ? "…" : entry.title)
                .font(Theme.rowTitle)
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 6) {
                Chip(
                    text: Formatters.mediumDate.string(from: entry.day),
                    systemImage: "calendar",
                    tint: entry.namedADay ? Theme.accent : Theme.textSecondary
                )
                if let time = entry.time {
                    Chip(text: Formatters.time.string(from: time), systemImage: "clock")
                } else {
                    Chip(text: "No time", systemImage: "clock", tint: Theme.textSecondary)
                }
                if entry.recurrence.repeats {
                    Chip(text: entry.recurrence.shortLabel, systemImage: "repeat")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.inset)
        }
        .opacity(canSave ? 1 : 0.45)
        .animation(.snappy(duration: 0.15), value: input)
    }

    // MARK: Saving

    private func draft() -> ItemDraft {
        let entry = parsed
        return ItemDraft(
            title: entry.title,
            kind: kind,
            day: entry.day,
            time: entry.time,
            isAllDay: false,
            notes: "",
            recurrence: entry.recurrence,
            colorIndex: kind == .reminder ? 4 : 0
        )
    }

    private func save() {
        guard canSave else { return }
        let item = draft().makeItem()
        context.insert(item)
        RecurrenceEngine.startSeries(for: item, in: context)
        try? context.save()

        Task { await NotificationScheduler.refresh(context: context, settings: settings) }
        dismiss()
    }
}
