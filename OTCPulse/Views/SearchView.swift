//
//  SearchView.swift
//  OTC Pulse
//
//  Full-text search across the entire accumulated history (title, summary,
//  regulator, tags) with filters: date range, region, regulator, topic,
//  minimum impact score. Runs entirely on-device against SwiftData.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var results: [Publication] = []
    @State private var hasSearched = false
    @State private var showFilters = false

    // Filters
    @State private var filterRegion: Region?
    @State private var filterRegulator: String = ""    // regulator code, "" = any
    @State private var filterTopic: String = ""        // tag, "" = any
    @State private var minImpact: Double = 0
    @State private var useDateRange = false
    @State private var fromDate = Calendar.current.date(byAdding: .month, value: -1, to: .now)!
    @State private var toDate = Date.now

    @Query(sort: \Regulator.code) private var regulators: [Regulator]

    private var activeFilterCount: Int {
        var n = 0
        if filterRegion != nil { n += 1 }
        if !filterRegulator.isEmpty { n += 1 }
        if !filterTopic.isEmpty { n += 1 }
        if minImpact > 0 { n += 1 }
        if useDateRange { n += 1 }
        return n
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Active filter chips
                    if activeFilterCount > 0 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                if let region = filterRegion { Chip(text: region.shortName) }
                                if !filterRegulator.isEmpty { Chip(text: filterRegulator) }
                                if !filterTopic.isEmpty { Chip(text: filterTopic, color: Theme.accentBlue) }
                                if minImpact > 0 { Chip(text: "≥ \(Formatters.score(minImpact))", color: Theme.warning) }
                                if useDateRange {
                                    Chip(text: "\(Formatters.shortDate.string(from: fromDate)) – \(Formatters.shortDate.string(from: toDate))",
                                         color: Theme.positive)
                                }
                                Button("Clear") { clearFilters() }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.alert)
                            }
                        }
                        .scrollClipDisabled()
                    }

                    if !hasSearched {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "Search the archive",
                            message: "Full-text search across every publication ever ingested — titles, summaries, regulators and tags."
                        )
                    } else if results.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "No results",
                            message: "Nothing in the archive matches your query and filters."
                        )
                    } else {
                        SectionHeader(title: "\(results.count) results", subtitle: "Newest first")
                        LazyVStack(spacing: 10) {
                            ForEach(results) { publication in
                                PublicationCard(publication: publication, compact: true)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $searchText, prompt: "Title, summary, regulator, tag…")
        .onSubmit(of: .search) { runSearch() }
        .onChange(of: searchText) { _, newValue in
            // Live search once the query is meaningful; clearing resets.
            if newValue.isEmpty { results = []; hasSearched = false }
            else if newValue.count >= 2 { runSearch() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: activeFilterCount > 0
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters, onDismiss: { if hasSearched { runSearch() } }) {
            filterSheet
        }
    }

    // MARK: - Search execution

    private func runSearch() {
        hasSearched = true
        let query = searchText.trimmingCharacters(in: .whitespaces)

        // Stage 1 — index-backed text predicate on the persistent store.
        var descriptor: FetchDescriptor<Publication>
        if query.isEmpty {
            descriptor = FetchDescriptor<Publication>()
        } else {
            descriptor = FetchDescriptor<Publication>(predicate: #Predicate {
                $0.title.localizedStandardContains(query)
                || $0.summary.localizedStandardContains(query)
                || $0.regulatorName.localizedStandardContains(query)
                || $0.regulatorCode.localizedStandardContains(query)
            })
        }
        descriptor.sortBy = [SortDescriptor(\Publication.publicationDate, order: .reverse)]
        var fetched = (try? context.fetch(descriptor)) ?? []

        // Stage 1b — tag matches (arrays aren't predicate-friendly; merge in-memory).
        if !query.isEmpty {
            let all = (try? context.fetch(FetchDescriptor<Publication>())) ?? []
            let ids = Set(fetched.map(\.id))
            let tagMatches = all.filter { pub in
                !ids.contains(pub.id) && pub.tags.contains { $0.localizedStandardContains(query) }
            }
            fetched.append(contentsOf: tagMatches)
            fetched.sort { $0.publicationDate > $1.publicationDate }
        }

        // Stage 2 — apply structured filters.
        results = fetched.filter { pub in
            if let region = filterRegion, pub.region != region.rawValue { return false }
            if !filterRegulator.isEmpty, pub.regulatorCode != filterRegulator { return false }
            if !filterTopic.isEmpty, !pub.tags.contains(filterTopic) { return false }
            if pub.impactScore < minImpact { return false }
            if useDateRange {
                let dayEnd = Calendar.current.date(byAdding: .day, value: 1,
                                                   to: Calendar.current.startOfDay(for: toDate))!
                if pub.publicationDate < Calendar.current.startOfDay(for: fromDate)
                    || pub.publicationDate >= dayEnd { return false }
            }
            return true
        }
    }

    private func clearFilters() {
        filterRegion = nil
        filterRegulator = ""
        filterTopic = ""
        minImpact = 0
        useDateRange = false
        if hasSearched { runSearch() }
    }

    // MARK: - Filter sheet

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Region") {
                    Picker("Region", selection: $filterRegion) {
                        Text("Any").tag(Region?.none)
                        ForEach(Region.allCases) { region in
                            Text(region.rawValue).tag(Region?.some(region))
                        }
                    }
                }
                Section("Regulator") {
                    Picker("Regulator", selection: $filterRegulator) {
                        Text("Any").tag("")
                        ForEach(regulators) { regulator in
                            Text("\(regulator.code) — \(regulator.name)").tag(regulator.code)
                        }
                    }
                }
                Section("Topic") {
                    Picker("Topic", selection: $filterTopic) {
                        Text("Any").tag("")
                        ForEach(Topics.predefined, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Minimum impact score: \(Formatters.score(minImpact))") {
                    Slider(value: $minImpact, in: 0...10, step: 0.5)
                        .tint(Theme.accent)
                }
                Section {
                    Toggle("Limit to date range", isOn: $useDateRange)
                    if useDateRange {
                        DatePicker("From", selection: $fromDate, displayedComponents: .date)
                        DatePicker("To", selection: $toDate, displayedComponents: .date)
                    }
                } header: { Text("Date range") }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { clearFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { showFilters = false }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }
}
