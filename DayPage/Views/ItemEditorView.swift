//
//  ItemEditorView.swift
//  DayPage
//
//  Full editor for one event or reminder — also the second step of quick add
//  when "More options" is tapped. Series edits offer to travel to every
//  future occurrence.
//

import SwiftUI
import SwiftData

// MARK: - Draft

/// A plain value version of `AgendaItem`, so the editor can work on
/// something that is not yet in the store.
struct ItemDraft: Identifiable {
    let id = UUID()
    var title: String = ""
    var kind: ItemKind = .event
    var day: Date = Calendar.current.startOfDay(for: .now)
    var time: Date?
    var isAllDay: Bool = false
    var notes: String = ""
    var recurrence: Recurrence = .none
    var colorIndex: Int = 0

    init(
        title: String = "",
        kind: ItemKind = .event,
        day: Date = Calendar.current.startOfDay(for: .now),
        time: Date? = nil,
        isAllDay: Bool = false,
        notes: String = "",
        recurrence: Recurrence = .none,
        colorIndex: Int = 0
    ) {
        self.title = title
        self.kind = kind
        self.day = Calendar.current.startOfDay(for: day)
        self.time = time
        self.isAllDay = isAllDay
        self.notes = notes
        self.recurrence = recurrence
        self.colorIndex = colorIndex
    }

    init(from item: AgendaItem) {
        self.init(
            title: item.title,
            kind: item.kind,
            day: item.day,
            time: item.time,
            isAllDay: item.isAllDay,
            notes: item.notes,
            recurrence: item.recurrence,
            colorIndex: item.colorIndex
        )
    }

    func makeItem() -> AgendaItem {
        AgendaItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            day: day,
            time: isAllDay ? nil : time,
            isAllDay: kind == .event && isAllDay,
            notes: notes,
            recurrence: recurrence,
            colorIndex: colorIndex
        )
    }

    /// Copies the draft onto an existing row.
    func apply(to item: AgendaItem) {
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.kind = kind
        item.day = Calendar.current.startOfDay(for: day)
        item.time = isAllDay ? nil : time.map { RecurrenceEngine.time(on: day, likeThatOf: $0) }
        item.isAllDay = kind == .event && isAllDay
        item.notes = notes
        item.colorIndex = colorIndex
        item.recurrence = recurrence
    }
}

// MARK: - Editor

@MainActor
struct ItemEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @State private var draft: ItemDraft
    @State private var hasTime: Bool
    @State private var applyToSeries = true
    @State private var showDeleteOptions = false

    /// The row being edited, or `nil` when creating.
    private let existing: AgendaItem?
    private let originalRecurrence: Recurrence

    init(target: EditorTarget) {
        switch target {
        case .existing(let item):
            existing = item
            _draft = State(initialValue: ItemDraft(from: item))
            _hasTime = State(initialValue: item.time != nil && !item.isAllDay)
            originalRecurrence = item.recurrence
        case .draft(let draft):
            existing = nil
            _draft = State(initialValue: draft)
            _hasTime = State(initialValue: draft.time != nil)
            originalRecurrence = draft.recurrence
        }
    }

    private var isSeriesMember: Bool { existing?.seriesID != nil }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title, axis: .vertical)
                        .lineLimit(1...3)

                    Picker("Kind", selection: $draft.kind) {
                        ForEach(ItemKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("When") {
                    DatePicker(
                        "Day",
                        selection: Binding(
                            get: { draft.day },
                            set: { draft.day = Calendar.current.startOfDay(for: $0) }
                        ),
                        displayedComponents: .date
                    )

                    if draft.kind == .event {
                        Toggle("All day", isOn: $draft.isAllDay)
                            .onChange(of: draft.isAllDay) { _, isOn in
                                if isOn { hasTime = false }
                            }
                    }

                    if !(draft.kind == .event && draft.isAllDay) {
                        Toggle("Set a time", isOn: $hasTime)
                            .onChange(of: hasTime) { _, isOn in
                                draft.time = isOn ? (draft.time ?? defaultTime) : nil
                            }

                        if hasTime {
                            DatePicker(
                                "Time",
                                selection: Binding(
                                    get: { draft.time ?? defaultTime },
                                    set: { draft.time = $0 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }

                    Picker("Repeat", selection: $draft.recurrence) {
                        ForEach(Recurrence.allCases) { rule in
                            Text(rule.label).tag(rule)
                        }
                    }
                }

                Section("Colour") {
                    colorPicker
                }

                Section("Notes") {
                    TextField("Anything worth remembering", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if isSeriesMember {
                    Section {
                        Toggle("Apply to future occurrences", isOn: $applyToSeries)
                    } footer: {
                        Text("Off: only this day changes, and it leaves the series.")
                    }
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            if isSeriesMember { showDeleteOptions = true } else { deleteItem(wholeSeries: false) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .confirmationDialog("This is a repeating item", isPresented: $showDeleteOptions, titleVisibility: .visible) {
                Button("Delete this occurrence", role: .destructive) { deleteItem(wholeSeries: false) }
                Button("Delete all occurrences", role: .destructive) { deleteItem(wholeSeries: true) }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private var defaultTime: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: draft.day)
        parts.hour = 9
        parts.minute = 0
        return Calendar.current.date(from: parts) ?? draft.day
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(Array(Theme.itemColors.enumerated()), id: \.offset) { index, color in
                Button {
                    draft.colorIndex = index
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Circle()
                                .strokeBorder(Theme.textPrimary.opacity(draft.colorIndex == index ? 0.8 : 0), lineWidth: 2)
                                .padding(-3)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Theme.colorNames[index])
                .accessibilityAddTraits(draft.colorIndex == index ? [.isSelected, .isButton] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    // MARK: Actions

    private func save() {
        guard canSave else { return }

        if let item = existing {
            let ruleChanged = draft.recurrence != originalRecurrence
            let leavingSeries = isSeriesMember && !applyToSeries

            if leavingSeries {
                // Detach this day from the series before editing it.
                if let seriesID = item.seriesID,
                   let master = RecurrenceEngine.master(ofSeries: seriesID, in: context),
                   master.id != item.id {
                    master.exceptionKeys.append(item.dayKey)
                }
                item.seriesID = nil
                item.isSeriesMaster = false
                draft.recurrence = .none
                draft.apply(to: item)
            } else {
                draft.apply(to: item)

                if let seriesID = item.seriesID,
                   let master = RecurrenceEngine.master(ofSeries: seriesID, in: context) {
                    if master.id != item.id { draft.apply(to: master) }
                    if ruleChanged {
                        RecurrenceEngine.rebuild(master, in: context)
                    } else {
                        RecurrenceEngine.propagate(from: master, in: context)
                    }
                } else if draft.recurrence.repeats {
                    RecurrenceEngine.startSeries(for: item, in: context)
                }
            }
        } else {
            let item = draft.makeItem()
            context.insert(item)
            RecurrenceEngine.startSeries(for: item, in: context)
        }

        try? context.save()
        Task { await NotificationScheduler.refresh(context: context, settings: settings) }
        dismiss()
    }

    private func deleteItem(wholeSeries: Bool) {
        guard let item = existing else { return }
        NotificationScheduler.cancel(itemID: item.id)
        if wholeSeries {
            RecurrenceEngine.deleteSeries(item, in: context)
        } else {
            RecurrenceEngine.deleteOccurrence(item, in: context)
        }
        try? context.save()
        Task { await NotificationScheduler.refresh(context: context, settings: settings) }
        dismiss()
    }
}
