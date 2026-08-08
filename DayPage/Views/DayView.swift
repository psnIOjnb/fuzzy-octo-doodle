//
//  DayView.swift
//  DayPage
//
//  The whole app is one screen: a day picker, the day's agenda and the day's
//  note. Everything else (calendar, settings, editors) is a sheet on top.
//

import SwiftUI
import SwiftData

@MainActor
struct DayView: View {

    @Environment(DayStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var showQuickAdd = false
    @State private var editorTarget: EditorTarget?
    @State private var wasShowingToday = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                DayHeaderBar(
                    onCalendar: { showCalendar = true },
                    onSettings: { showSettings = true }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headline

                        DayPageContent(
                            day: store.selectedDay,
                            onAdd: { showQuickAdd = true },
                            onEdit: { editorTarget = .existing($0) }
                        )
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(daySwipe)
            }
        }
        .animation(.snappy(duration: 0.22), value: store.selectedDay)
        .sheet(isPresented: $showCalendar) {
            CalendarSheet(onPick: { store.select($0) })
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(
                day: store.selectedDay,
                onOpenFullEditor: { draft in
                    showQuickAdd = false
                    // Let the first sheet finish dismissing before the next.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        editorTarget = .draft(draft)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editorTarget) { target in
            ItemEditorView(target: target)
        }
        .task {
            await bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.refreshForNewDayIfNeeded(wasShowingToday: wasShowingToday)
                RecurrenceEngine.materializeAll(in: context)
            case .background:
                wasShowingToday = store.isToday
            default:
                break
            }
        }
    }

    // MARK: Headline

    private var headline: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(store.headline(for: store.selectedDay))
                .font(Theme.display)
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Spacer(minLength: 8)

            if !store.isToday {
                Button("Today") { store.goToToday() }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Gestures

    /// Horizontal flick anywhere on the page moves a day. Runs alongside the
    /// scroll view's own gesture, so vertical scrolling is untouched.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 2 else { return }
                if dx < 0 { store.goToNextDay() } else { store.goToPreviousDay() }
            }
    }

    // MARK: Launch work

    private func bootstrap() async {
        if !settings.hasSeededWelcomeContent {
            WelcomeContent.seed(into: context)
            settings.hasSeededWelcomeContent = true
        }
        RecurrenceEngine.materializeAll(in: context)
        await NotificationScheduler.refresh(context: context, settings: settings)
        await NotificationScheduler.refreshNoteNudge(settings: settings)
    }
}

// MARK: - Editor routing

/// What the item editor was opened for: an existing row, or a new one
/// pre-filled by quick add.
enum EditorTarget: Identifiable {
    case existing(AgendaItem)
    case draft(ItemDraft)

    var id: String {
        switch self {
        case .existing(let item): "item-\(item.id.uuidString)"
        case .draft(let draft): "draft-\(draft.id.uuidString)"
        }
    }
}

// MARK: - One day's data

/// Owns the day-scoped queries. Re-initialised whenever the day changes,
/// which is what makes the `@Query` predicates follow the selection.
@MainActor
private struct DayPageContent: View {

    let day: Date
    let onAdd: () -> Void
    let onEdit: (AgendaItem) -> Void

    @Environment(AppSettings.self) private var settings

    @Query private var dayItems: [AgendaItem]
    @Query private var overdueItems: [AgendaItem]
    @Query private var notes: [DailyNote]

    init(day: Date, onAdd: @escaping () -> Void, onEdit: @escaping (AgendaItem) -> Void) {
        self.day = day
        self.onAdd = onAdd
        self.onEdit = onEdit

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        _dayItems = Query(
            filter: #Predicate<AgendaItem> { $0.day >= start && $0.day < end },
            sort: \AgendaItem.createdAt,
            order: .forward
        )

        // Unfinished reminders from earlier days only surface on today's page.
        let cutoff = calendar.isDateInToday(start) ? start : Date.distantPast
        let reminderRaw = ItemKind.reminder.rawValue
        _overdueItems = Query(
            filter: #Predicate<AgendaItem> {
                $0.day < cutoff && $0.kindRaw == reminderRaw && !$0.isCompleted
            },
            sort: \AgendaItem.day,
            order: .forward
        )

        let key = DayKey.key(for: start)
        _notes = Query(
            filter: #Predicate<DailyNote> { $0.dayKey == key },
            sort: \DailyNote.updatedAt,
            order: .reverse
        )
    }

    private var overdue: [AgendaItem] {
        settings.rollOverdueReminders ? overdueItems : []
    }

    var body: some View {
        VStack(spacing: 16) {
            AgendaCard(
                items: dayItems,
                overdue: overdue,
                onAdd: onAdd,
                onEdit: onEdit
            )

            DailyNoteCard(
                day: day,
                note: notes.first,
                shareText: { DayExporter.markdown(for: day, items: dayItems + overdue, note: notes.first) }
            )
        }
    }
}
