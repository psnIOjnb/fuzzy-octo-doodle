//
//  PublicationCard.swift
//  OTC Pulse
//
//  The signature glassmorphic publication card used across every tab.
//

import SwiftUI
import SwiftData

struct PublicationCard: View {
    let publication: Publication
    /// Compact cards hide the summary (used in dense historical lists).
    var compact: Bool = false

    var body: some View {
        NavigationLink {
            PublicationDetailView(publication: publication)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: regulator + type + impact
                HStack(spacing: 8) {
                    Chip(text: publication.regulatorCode)
                    Text(publication.documentType)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    ImpactBadge(score: publication.impactScore)
                }

                Text(publication.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if !compact {
                    Text(publication.summary)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Bottom row: tags + timestamp
                HStack(spacing: 6) {
                    ForEach(publication.tags.prefix(compact ? 2 : 3), id: \.self) { tag in
                        Chip(text: tag, color: Theme.accentBlue)
                    }
                    Spacer()
                    Text(publication.publicationDate, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary.opacity(0.8))
                }
            }
            .padding(14)
            .glassCard(glow: publication.isHighImpact)
        }
        .buttonStyle(.plain)
    }
}

/// Circular-gauge style impact score badge, color-coded by severity.
struct ImpactBadge: View {
    let score: Double

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.impactColor(score))
                .frame(width: 6, height: 6)
                .shadow(color: Theme.impactColor(score).opacity(0.9), radius: 3)
            Text(Formatters.score(score))
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.impactColor(score))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Theme.impactColor(score).opacity(0.10), in: Capsule())
    }
}
