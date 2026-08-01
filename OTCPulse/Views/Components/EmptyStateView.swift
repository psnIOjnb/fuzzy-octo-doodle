//
//  EmptyStateView.swift
//  OTC Pulse
//
//  Premium empty state: soft cyan glow ring around the symbol, quiet copy.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.06))
                    .frame(width: 96, height: 96)
                Circle()
                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.accentGradient)
            }
            .shadow(color: Theme.accent.opacity(0.25), radius: 24)

            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
