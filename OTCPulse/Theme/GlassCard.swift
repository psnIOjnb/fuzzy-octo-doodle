//
//  GlassCard.swift
//  OTC Pulse
//
//  Glassmorphic card treatment: subtle material blur over the navy base,
//  a thin gradient "glow" border, and a soft shadow.
//

import SwiftUI

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 18
    /// Set true to emphasize the card with a stronger cyan border glow.
    var glow: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Theme.surface.opacity(0.55))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: glow
                                ? [Theme.accent.opacity(0.65), Theme.accentBlue.opacity(0.25), Theme.accent.opacity(0.4)]
                                : [Color.white.opacity(0.14), Theme.hairline.opacity(0.7), Color.white.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: glow ? Theme.accent.opacity(0.18) : .black.opacity(0.35),
                    radius: glow ? 14 : 10, x: 0, y: 6)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 18, glow: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, glow: glow))
    }
}

/// Small cyan-tinted capsule chip used for tags, codes and filters.
struct Chip: View {
    let text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.5))
    }
}

/// Section header used across scrollable screens.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .kerning(1.4)
                .foregroundStyle(Theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
