//
//  RegulatorsView.swift
//  OTC Pulse
//
//  Searchable regulator directory; tapping one opens its full historical
//  publication archive.
//

import SwiftUI
import SwiftData

struct RegulatorsView: View {
    @Query(sort: \Regulator.name) private var regulators: [Regulator]
    @Query private var allPublications: [Publication]
    @State private var searchText = ""

    private var filtered: [Regulator] {
        guard !searchText.isEmpty else { return regulators }
        return regulators.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
                || $0.country.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Historical publication counts per regulator code.
    private var counts: [String: Int] {
        Dictionary(grouping: allPublications, by: \.regulatorCode).mapValues(\.count)
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                LazyVStack(spacing: 10) {
                    if filtered.isEmpty {
                        EmptyStateView(
                            icon: "building.columns",
                            title: "No matches",
                            message: "No regulator matches \"\(searchText)\"."
                        )
                    }
                    ForEach(filtered) { regulator in
                        NavigationLink {
                            RegulatorDetailView(regulator: regulator)
                        } label: {
                            HStack(spacing: 12) {
                                // Code monogram
                                Text(regulator.code)
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 58, height: 40)
                                    .background(Theme.accent.opacity(0.08),
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(Theme.accent.opacity(0.3), lineWidth: 0.5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(regulator.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text("\(regulator.country) · \(regulator.region)")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(counts[regulator.code] ?? 0)")
                                        .font(.subheadline.weight(.bold).monospacedDigit())
                                        .foregroundStyle(Theme.accent)
                                    Text("DOCS")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(12)
                            .glassCard(cornerRadius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Regulators")
        .searchable(text: $searchText, prompt: "Name, code or country")
    }
}

/// Full historical archive for one regulator.
struct RegulatorDetailView: View {
    let regulator: Regulator
    @Query private var publications: [Publication]

    init(regulator: Regulator) {
        self.regulator = regulator
        let code = regulator.code
        _publications = Query(
            filter: #Predicate<Publication> { $0.regulatorCode == code },
            sort: [SortDescriptor(\Publication.publicationDate, order: .reverse)]
        )
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(regulator.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(regulator.country) · \(regulator.region)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 14) {
                            Label("\(publications.count) publications", systemImage: "doc.text")
                            Label("\(publications.filter(\.isHighImpact).count) high impact", systemImage: "bolt.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 4)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(glow: true)

                    SectionHeader(title: "Full History")

                    if publications.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "No publications yet",
                            message: "Nothing from \(regulator.code) has been ingested so far."
                        )
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
        .navigationTitle(regulator.code)
        .navigationBarTitleDisplayMode(.inline)
    }
}
