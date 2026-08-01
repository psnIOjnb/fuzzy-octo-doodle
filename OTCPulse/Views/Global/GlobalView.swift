//
//  GlobalView.swift
//  OTC Pulse
//
//  Default home: today's 24-hour global snapshot — stats strip, world
//  heatmap, and the day's publication cards. Pull to refresh; export the
//  day to PDF from the toolbar.
//

import SwiftUI
import SwiftData

struct GlobalView: View {
    @Environment(DataService.self) private var dataService

    /// Today's publications, highest impact first.
    @Query private var todays: [Publication]

    @State private var exportedPDF: URL?

    init() {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        _todays = Query(
            filter: #Predicate<Publication> { $0.publicationDate >= startOfToday },
            sort: [SortDescriptor(\Publication.impactScore, order: .reverse)]
        )
    }

    private var highImpactCount: Int { todays.filter(\.isHighImpact).count }

    private var regionCounts: [(region: Region, count: Int)] {
        Region.allCases.map { region in
            (region, todays.filter { $0.region == region.rawValue }.count)
        }
    }

    private var stats: [StatItem] {
        var items: [StatItem] = [
            StatItem(label: "Publications", value: "\(todays.count)", color: Theme.accent),
            StatItem(label: "High Impact", value: "\(highImpactCount)", color: Theme.alert),
        ]
        for entry in regionCounts where entry.count > 0 {
            items.append(StatItem(label: entry.region.shortName, value: "\(entry.count)", color: Theme.accentBlue))
        }
        return items
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Date line
                    Text(Formatters.dayHeader.string(from: .now))
                        .font(.caption.weight(.semibold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.textSecondary)

                    // Stats strip
                    StatsStrip(stats: stats)

                    // World heatmap
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Global Activity", subtitle: "Last 24 hours · glow intensity = volume, red = high impact")
                        HeatmapView(points: makeHeatPoints(from: todays))
                    }
                    .padding(14)
                    .glassCard()

                    // Refresh error surface
                    if let error = dataService.lastError {
                        Label(error, systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(Theme.warning)
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                    }

                    // Today's publications
                    SectionHeader(title: "Today's Publications",
                                  subtitle: todays.isEmpty ? nil : "Sorted by impact score")

                    if todays.isEmpty {
                        EmptyStateView(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "No intel yet today",
                            message: "Pull down to refresh the daily feed. Yesterday's data stays available in the Library."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(todays) { publication in
                                PublicationCard(publication: publication)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .refreshable {
                await dataService.refresh()
            }
        }
        .navigationTitle("OTC Pulse")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let pdf = exportedPDF {
                    ShareLink(item: pdf) {
                        Image(systemName: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        exportedPDF = try? PDFExporter.exportDailySnapshot(date: .now, publications: todays)
                    } label: {
                        Image(systemName: "doc.badge.arrow.up")
                    }
                    .disabled(todays.isEmpty)
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                if dataService.isRefreshing {
                    ProgressView().tint(Theme.accent)
                }
            }
        }
    }
}
