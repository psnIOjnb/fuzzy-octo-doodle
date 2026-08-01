//
//  HighImpactView.swift
//  OTC Pulse
//
//  Priority intel: only publications with impactScore >= 7.5, across the
//  full accumulated history, newest first.
//

import SwiftUI
import SwiftData

struct HighImpactView: View {
    @Query private var highImpact: [Publication]

    init() {
        let threshold = AppConfig.highImpactThreshold
        _highImpact = Query(
            filter: #Predicate<Publication> { $0.impactScore >= threshold },
            sort: [SortDescriptor(\Publication.publicationDate, order: .reverse)]
        )
    }

    private var todayCount: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return highImpact.filter { $0.publicationDate >= start }.count
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StatsStrip(stats: [
                        .init(label: "All Time", value: "\(highImpact.count)", color: Theme.alert),
                        .init(label: "Today", value: "\(todayCount)", color: Theme.accent),
                        .init(label: "Threshold", value: "≥ \(Formatters.score(AppConfig.highImpactThreshold))",
                              color: Theme.textSecondary),
                    ])

                    SectionHeader(title: "High-Impact Publications",
                                  subtitle: "Impact score \(Formatters.score(AppConfig.highImpactThreshold)) or higher")

                    if highImpact.isEmpty {
                        EmptyStateView(
                            icon: "bolt.slash",
                            title: "No high-impact intel",
                            message: "Publications scoring \(Formatters.score(AppConfig.highImpactThreshold))+ will surface here the moment they land."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(highImpact) { publication in
                                PublicationCard(publication: publication)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("High Impact")
    }
}
