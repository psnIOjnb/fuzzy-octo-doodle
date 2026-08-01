//
//  WatchlistView.swift
//  OTC Pulse
//
//  User-saved publications with personal notes. High-impact alert opt-in
//  lives in Settings; saved items are plain SwiftData rows so they work
//  fully offline.
//

import SwiftUI
import SwiftData

struct WatchlistView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchlistItem.dateAdded, order: .reverse)
    private var items: [WatchlistItem]

    var body: some View {
        ZStack {
            Theme.backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if items.isEmpty {
                        EmptyStateView(
                            icon: "star",
                            title: "Watchlist is empty",
                            message: "Save any publication from its detail page to track it here and attach personal notes."
                        )
                    } else {
                        SectionHeader(title: "\(items.count) saved", subtitle: "Newest first")
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                if let publication = item.publication {
                                    VStack(alignment: .leading, spacing: 8) {
                                        PublicationCard(publication: publication, compact: true)

                                        if let note = item.note, !note.isEmpty {
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: "note.text")
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.warning)
                                                Text(note)
                                                    .font(.caption)
                                                    .foregroundStyle(Theme.textSecondary)
                                                    .lineLimit(3)
                                            }
                                            .padding(.horizontal, 6)
                                        }

                                        HStack {
                                            Text("Added \(item.dateAdded, format: .relative(presentation: .named))")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Theme.textSecondary.opacity(0.7))
                                            Spacer()
                                            Button(role: .destructive) {
                                                context.delete(item)
                                                try? context.save()
                                            } label: {
                                                Label("Remove", systemImage: "star.slash")
                                                    .font(.caption2.weight(.semibold))
                                            }
                                            .foregroundStyle(Theme.alert)
                                        }
                                        .padding(.horizontal, 6)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Watchlist")
    }
}
