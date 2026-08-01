//
//  Region.swift
//  OTC Pulse
//
//  Region taxonomy + the pre-defined topic list used across the app.
//

import Foundation
import SwiftUI

enum Region: String, CaseIterable, Identifiable, Codable {
    case americas = "Americas"
    case europe = "Europe"
    case asiaPacific = "Asia-Pacific"
    case mea = "MEA"
    case international = "International Bodies"

    var id: String { rawValue }

    /// Short label for dense UI (chips, segmented pickers).
    var shortName: String {
        switch self {
        case .americas: "Americas"
        case .europe: "Europe"
        case .asiaPacific: "APAC"
        case .mea: "MEA"
        case .international: "Intl"
        }
    }

    var symbol: String {
        switch self {
        case .americas: "globe.americas.fill"
        case .europe: "globe.europe.africa.fill"
        case .asiaPacific: "globe.asia.australia.fill"
        case .mea: "globe.central.south.asia.fill"
        case .international: "building.columns.fill"
        }
    }
}

/// Pre-defined topic taxonomy. Publications may also carry dynamic tags
/// beyond this list; the Topics tab merges both.
enum Topics {
    static let predefined: [String] = [
        "Margin",
        "CCP Risk",
        "Trade Reporting",
        "Trading Venues",
        "Capital Requirements",
        "Cross-border",
        "Clearing Obligation",
        "Benchmarks",
        "Crypto Derivatives",
        "Position Limits",
        "Market Conduct",
        "Netting",
    ]

    static func symbol(for topic: String) -> String {
        switch topic {
        case "Margin": "percent"
        case "CCP Risk": "shield.lefthalf.filled"
        case "Trade Reporting": "doc.text.magnifyingglass"
        case "Trading Venues": "building.2.fill"
        case "Capital Requirements": "banknote.fill"
        case "Cross-border": "arrow.left.arrow.right"
        case "Clearing Obligation": "arrow.triangle.branch"
        case "Benchmarks": "chart.xyaxis.line"
        case "Crypto Derivatives": "bitcoinsign.circle.fill"
        case "Position Limits": "gauge.with.needle.fill"
        case "Market Conduct": "eye.fill"
        case "Netting": "square.stack.3d.down.right.fill"
        default: "tag.fill"
        }
    }
}
