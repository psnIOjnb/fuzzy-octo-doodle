//
//  LibraryView.swift
//  OTC Pulse
//
//  The permanent archive: browse every accumulated day, grouped by month,
//  and open any past daily snapshot (with PDF export).
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Query(sort: \DailySnapshot.date, order: .reverse)
    private var snapshots: [DailySnapshot]

    /// Snapshots grouped into (month header, days) sections, newest first.
    private var months: [(header: String, days: [DailySnapshot])] {
        let grouped = Dictionary(grouping: snapshots) { snapshot in
            Formatters.monthYear.string(from: snapshot.date)
        }
        // Preserve newest-first ordering using each group's newest day.
        return grouped
            .map { (header: $0.key, days: $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.days.first?.date ?? .distantPast) > ($1.days.first?.date ?? .distantPast) }
    }

    private var totals: (docs: Int, high: Int) {
        (snapshots.reduce(0) { $0 + $1.totalCount },
         snapshots.reduce(0) { $0 + $1.highImpactCount })
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatsStrip(stats: [
                        .init(label: "Days Archived", value: "\(snapshots.count)", color: Theme.accent),
                        .init(label: "Total Docs", value: "\(totals.docs)", color: Theme.accentBlue),
                        .init(label: "High Impact", value: "\(totals.high)", color: Theme.alert),
                    ])

                    if snapshots.isEmpty {
                        EmptyStateView(
                            icon: "books.vertical",
                            title: "Archive is empty",
                            message: "Every day's snapshot accumulates here permanently after each refresh."
                        )
                    }

                    ForEach(months, id: \.header) { month in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: month.header)
                            LazyVStack(spacing: 8) {
                                ForEach(month.days) { snapshot in
                                    NavigationLink {
                                        DayDetailView(snapshot: snapshot)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(snapshot.date, format: .dateTime.day())
                                                .font(.title3.weight(.bold).monospacedDigit())
                                                .foregroundStyle(Theme.accent)
                                                .frame(width: 40, height: 40)
                                                .background(Theme.accent.opacity(0.08),
                                                            in: RoundedRectangle(cornerRadius: 10))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(snapshot.date, format: .dateTime.weekday(.wide))
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(Theme.textPrimary)
                                                Text("\(snapshot.totalCount) publications")
                                                    .font(.caption2)
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            Spacer()
                                            if snapshot.highImpactCount > 0 {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "bolt.fill").font(.system(size: 9))
                                                    Text("\(snapshot.highImpactCount)")
                                                        .font(.caption.weight(.bold).monospacedDigit())
                                                }
                                                .foregroundStyle(Theme.alert)
                                            }
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Theme.textSecondary.opacity(0.5))
                                        }
                                        .padding(10)
                                        .glassCard(cornerRadius: 14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Library")
    }
}

/// One archived day: its stats and all its publications, with PDF export.
struct DayDetailView: View {
    let snapshot: DailySnapshot
    @Query private var publications: [Publication]
    @State private var exportedPDF: URL?

    init(snapshot: DailySnapshot) {
        self.snapshot = snapshot
        let dayStart = Calendar.current.startOfDay(for: snapshot.date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        _publications = Query(
            filter: #Predicate<Publication> {
                $0.publicationDate >= dayStart && $0.publicationDate < dayEnd
            },
            sort: [SortDescriptor(\Publication.impactScore, order: .reverse)]
        )
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    StatsStrip(stats: [
                        .init(label: "Publications", value: "\(publications.count)", color: Theme.accent),
                        .init(label: "High Impact",
                              value: "\(publications.filter(\.isHighImpact).count)", color: Theme.alert),
                    ])

                    if publications.isEmpty {
                        EmptyStateView(icon: "tray", title: "Empty day",
                                       message: "No publications stored for this date.")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(publications) { publication in
                                PublicationCard(publication: publication, compact: true)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(Formatters.shortDate.string(from: snapshot.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let pdf = exportedPDF {
                    ShareLink(item: pdf) { Image(systemName: "square.and.arrow.up") }
                } else {
                    Button {
                        exportedPDF = try? PDFExporter.exportDailySnapshot(
                            date: snapshot.date, publications: publications)
                    } label: {
                        Image(systemName: "doc.badge.arrow.up")
                    }
                    .disabled(publications.isEmpty)
                }
            }
        }
    }
}
