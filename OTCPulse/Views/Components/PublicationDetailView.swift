//
//  PublicationDetailView.swift
//  OTC Pulse
//
//  Full record view: metadata, summary, deadline, tags, source link,
//  and watchlist save with a personal note.
//

import SwiftUI
import SwiftData

struct PublicationDetailView: View {
    let publication: Publication

    @Environment(\.modelContext) private var context
    @Query private var watchlistMatches: [WatchlistItem]
    @State private var showNoteEditor = false
    @State private var noteDraft = ""

    init(publication: Publication) {
        self.publication = publication
        let pubID = publication.id
        _watchlistMatches = Query(filter: #Predicate<WatchlistItem> { $0.publicationID == pubID })
    }

    private var watchlistItem: WatchlistItem? { watchlistMatches.first }

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header block
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Chip(text: publication.regulatorCode)
                            Chip(text: publication.region, color: Theme.accentBlue)
                            Spacer()
                            ImpactBadge(score: publication.impactScore)
                        }

                        Text(publication.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            LabeledContent { Text(publication.regulatorName) } label: { Text("Regulator") }
                            LabeledContent { Text(publication.documentType) } label: { Text("Type") }
                            LabeledContent {
                                Text(publication.publicationDate, format: .dateTime.day().month(.wide).year().hour().minute())
                            } label: { Text("Published") }
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(16)
                    .glassCard(glow: publication.isHighImpact)

                    // Deadline callout
                    if let deadlineDate = publication.deadlineDate, let label = publication.deadlineLabel {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title3)
                                .foregroundStyle(Theme.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                Text(deadlineDate, format: .dateTime.day().month(.wide).year())
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            Spacer()
                            Text(deadlineDate, format: .relative(presentation: .named))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                        }
                        .padding(14)
                        .glassCard()
                    }

                    // Summary
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Summary")
                        Text(publication.summary)
                            .font(.callout)
                            .foregroundStyle(Theme.textPrimary.opacity(0.9))
                            .lineSpacing(3)
                        if let fullText = publication.fullText, !fullText.isEmpty {
                            Divider().overlay(Theme.hairline)
                            Text(fullText)
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(16)
                    .glassCard()

                    // Tags
                    if !publication.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Tags")
                            FlowChips(tags: publication.tags)
                        }
                        .padding(16)
                        .glassCard()
                    }

                    // Personal note (when on watchlist)
                    if let item = watchlistItem, let note = item.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "My Note")
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        }
                        .padding(16)
                        .glassCard(glow: true)
                    }

                    // Actions
                    VStack(spacing: 10) {
                        Button {
                            toggleWatchlist()
                        } label: {
                            Label(watchlistItem == nil ? "Add to Watchlist" : "Remove from Watchlist",
                                  systemImage: watchlistItem == nil ? "star" : "star.slash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(watchlistItem == nil ? Theme.accent.opacity(0.85) : Theme.alert.opacity(0.85))
                        .foregroundStyle(.black)

                        if watchlistItem != nil {
                            Button {
                                noteDraft = watchlistItem?.note ?? ""
                                showNoteEditor = true
                            } label: {
                                Label("Edit Note", systemImage: "square.and.pencil")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accentBlue)
                        }

                        if let urlString = publication.url, let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("Open Source Document", systemImage: "arrow.up.right.square")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(publication.regulatorCode)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNoteEditor) { noteEditor }
    }

    private var noteEditor: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                TextEditor(text: $noteDraft)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .foregroundStyle(Theme.textPrimary)
            }
            .navigationTitle("Personal Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showNoteEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        watchlistItem?.note = noteDraft.isEmpty ? nil : noteDraft
                        try? context.save()
                        showNoteEditor = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func toggleWatchlist() {
        if let item = watchlistItem {
            context.delete(item)
        } else {
            context.insert(WatchlistItem(publication: publication))
        }
        try? context.save()
    }
}

/// Simple wrapping chip layout for tag clouds.
struct FlowChips: View {
    let tags: [String]

    var body: some View {
        // A simple grid keeps layout deterministic without a custom Layout.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8, alignment: .leading)],
                  alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Chip(text: tag, color: Theme.accentBlue)
            }
        }
    }
}
