//
//  StatsStrip.swift
//  OTC Pulse
//
//  Horizontally scrolling strip of large-numeral stat tiles.
//

import SwiftUI

struct StatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let color: Color
}

struct StatsStrip: View {
    let stats: [StatItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stat.value)
                            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(stat.color)
                            .contentTransition(.numericText())
                        Text(stat.label.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(1.0)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(minWidth: 96, alignment: .leading)
                    .glassCard(cornerRadius: 14)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
    }
}
