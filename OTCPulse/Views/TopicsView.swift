//
//  TopicsView.swift
//  OTC Pulse
//
//  Topic grid combining the pre-defined taxonomy with dynamic tags found
//  in the data. Tapping a topic opens all matching publications.
//

import SwiftUI
import SwiftData

struct TopicsView: View {
    @Query private var allPublications: [Publication]

    /// Pre-defined topics first (in taxonomy order), then dynamic tags by frequency.
    private var topics: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for pub in allPublications {
            for tag in pub.tags { counts[tag, default: 0] += 1 }
        }
        let predefined = Topics.predefined.map { ($0, counts[$0] ?? 0) }
        let dynamic = counts.keys
            .filter { !Topics.predefined.contains($0) }
            .sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
            .map { ($0, counts[$0] ?? 0) }
        return predefined + dynamic
    }

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Topics",
                                  subtitle: "Pre-defined taxonomy plus dynamic tags from the feed")

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(topics, id: \.name) { topic in
                            NavigationLink {
                                TopicDetailView(topic: topic.name)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: Topics.symbol(for: topic.name))
                                        .font(.title3)
                                        .foregroundStyle(Theme.accentGradient)
                                    Text(topic.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(2, reservesSpace: true)
                                        .multilineTextAlignment(.leading)
                                    Text("\(topic.count) documents")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .glassCard(cornerRadius: 16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Topics")
    }
}

/// All publications carrying a given tag, grouped newest first.
struct TopicDetailView: View {
    let topic: String
    @Query(sort: \Publication.publicationDate, order: .reverse)
    private var allPublications: [Publication]

    private var matching: [Publication] {
        allPublications.filter { $0.tags.contains(topic) }
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if matching.isEmpty {
                        EmptyStateView(
                            icon: Topics.symbol(for: topic),
                            title: "Nothing filed under \(topic)",
                            message: "Publications tagged \(topic) will appear here as they are ingested."
                        )
                    } else {
                        SectionHeader(title: "\(matching.count) documents", subtitle: "Entire history, newest first")
                        LazyVStack(spacing: 10) {
                            ForEach(matching) { publication in
                                PublicationCard(publication: publication, compact: true)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(topic)
        .navigationBarTitleDisplayMode(.inline)
    }
}
