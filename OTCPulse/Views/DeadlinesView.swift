//
//  DeadlinesView.swift
//  OTC Pulse
//
//  Timeline of every extracted compliance / consultation / effective date
//  across the accumulated history, bucketed by urgency.
//

import SwiftUI
import SwiftData

struct DeadlinesView: View {
    @Query private var withDeadlines: [Publication]

    init() {
        _withDeadlines = Query(
            filter: #Predicate<Publication> { $0.deadlineDate != nil },
            sort: [SortDescriptor(\Publication.deadlineDate, order: .forward)]
        )
    }

    private var buckets: [(title: String, color: Color, items: [Publication])] {
        let now = Date.now
        let calendar = Calendar.current
        let weekOut = calendar.date(byAdding: .day, value: 7, to: now)!
        let monthOut = calendar.date(byAdding: .day, value: 30, to: now)!

        var overdue: [Publication] = []
        var thisWeek: [Publication] = []
        var thisMonth: [Publication] = []
        var later: [Publication] = []

        for pub in withDeadlines {
            guard let deadline = pub.deadlineDate else { continue }
            if deadline < now { overdue.append(pub) }
            else if deadline <= weekOut { thisWeek.append(pub) }
            else if deadline <= monthOut { thisMonth.append(pub) }
            else { later.append(pub) }
        }

        return [
            (title: "Overdue / Passed", color: Theme.alert, items: Array(overdue.reversed())), // most recent first
            (title: "Next 7 Days", color: Theme.warning, items: thisWeek),
            (title: "Next 30 Days", color: Theme.accent, items: thisMonth),
            (title: "Later", color: Theme.accentBlue, items: later),
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if withDeadlines.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No tracked deadlines",
                            message: "Consultation close dates, effective dates and compliance deadlines extracted from the feed will line up here."
                        )
                    }

                    ForEach(buckets, id: \.title) { bucket in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle().fill(bucket.color).frame(width: 8, height: 8)
                                    .shadow(color: bucket.color.opacity(0.8), radius: 4)
                                Text(bucket.title.uppercased())
                                    .font(.caption.weight(.bold))
                                    .kerning(1.2)
                                    .foregroundStyle(bucket.color)
                                Spacer()
                                Text("\(bucket.items.count)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            LazyVStack(spacing: 10) {
                                ForEach(bucket.items) { publication in
                                    DeadlineRow(publication: publication, accent: bucket.color)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Deadlines")
    }
}

private struct DeadlineRow: View {
    let publication: Publication
    let accent: Color

    var body: some View {
        NavigationLink {
            PublicationDetailView(publication: publication)
        } label: {
            HStack(spacing: 12) {
                // Date block
                VStack(spacing: 1) {
                    if let deadline = publication.deadlineDate {
                        Text(deadline, format: .dateTime.day())
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(accent)
                        Text(deadline, format: .dateTime.month(.abbreviated))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text(deadline, format: .dateTime.year())
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    }
                }
                .frame(width: 48)
                .padding(.vertical, 8)
                .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.3), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text(publication.deadlineLabel ?? "Deadline")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(accent)
                    Text(publication.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(publication.regulatorCode)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        if let deadline = publication.deadlineDate {
                            Text(deadline, format: .relative(presentation: .named))
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.textSecondary.opacity(0.8))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}
