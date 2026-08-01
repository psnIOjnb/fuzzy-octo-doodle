//
//  RegionsView.swift
//  OTC Pulse
//
//  Region selector with filtered stats, a mini heatmap of the selected
//  region's activity, and today's publication cards for that region.
//

import SwiftUI
import SwiftData

struct RegionsView: View {
    @State private var selectedRegion: Region = .americas

    /// Today's publications across all regions (filtered in-memory per selection).
    @Query private var todays: [Publication]

    init() {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        _todays = Query(
            filter: #Predicate<Publication> { $0.publicationDate >= startOfToday },
            sort: [SortDescriptor(\Publication.impactScore, order: .reverse)]
        )
    }

    private var regionPubs: [Publication] {
        todays.filter { $0.region == selectedRegion.rawValue }
    }

    private var regulatorCount: Int {
        Set(regionPubs.map(\.regulatorCode)).count
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Region chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Region.allCases) { region in
                                Button {
                                    withAnimation(.snappy) { selectedRegion = region }
                                } label: {
                                    Label(region.shortName, systemImage: region.symbol)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedRegion == region
                                                ? Theme.accent.opacity(0.16)
                                                : Theme.surface.opacity(0.6),
                                            in: Capsule()
                                        )
                                        .overlay(
                                            Capsule().strokeBorder(
                                                selectedRegion == region
                                                    ? Theme.accent.opacity(0.6)
                                                    : Theme.hairline,
                                                lineWidth: 1
                                            )
                                        )
                                        .foregroundStyle(
                                            selectedRegion == region ? Theme.accent : Theme.textSecondary
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()

                    // Region stats
                    StatsStrip(stats: [
                        .init(label: "Publications", value: "\(regionPubs.count)", color: Theme.accent),
                        .init(label: "High Impact",
                              value: "\(regionPubs.filter(\.isHighImpact).count)", color: Theme.alert),
                        .init(label: "Regulators", value: "\(regulatorCount)", color: Theme.accentBlue),
                    ])

                    // Mini heatmap scoped to the region's activity
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "\(selectedRegion.rawValue) Activity", subtitle: "Last 24 hours")
                        HeatmapView(points: makeHeatPoints(from: regionPubs), height: 160)
                    }
                    .padding(14)
                    .glassCard()

                    SectionHeader(title: "Today in \(selectedRegion.rawValue)")

                    if regionPubs.isEmpty {
                        EmptyStateView(
                            icon: selectedRegion.symbol,
                            title: "Quiet in \(selectedRegion.rawValue)",
                            message: "No publications ingested for this region in the current 24-hour window."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(regionPubs) { publication in
                                PublicationCard(publication: publication)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Regions")
    }
}
