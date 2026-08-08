//
//  Cards.swift
//  DayPage
//
//  The shared furniture: the rounded card treatment, the small square icon
//  buttons in card headers, chips and the empty-state line.
//

import SwiftUI

// MARK: - Card

struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.card)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = Theme.cardPadding) -> some View {
        modifier(CardBackground(padding: padding))
    }
}

// MARK: - Icon button

/// Rounded-square button used in the header bar and card headers.
struct IconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var filled: Bool = false
    var tint: Color = Theme.accent
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(filled ? Color.white : tint)
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .fill(filled ? tint : tint.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Card header

/// "🗓 Agenda   [buttons]" — serif title, symbol, trailing controls.
struct CardHeader<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(title)
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
    }
}

// MARK: - Small parts

/// Uppercase caption above an agenda column.
struct ColumnCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.columnCaption)
            .kerning(0.8)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Compact tinted capsule for repeat rules, parsed times, counts.
struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

/// Placeholder shown in an empty agenda column or an empty search.
struct EmptyLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.rowSubtitle)
            .foregroundStyle(Theme.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
