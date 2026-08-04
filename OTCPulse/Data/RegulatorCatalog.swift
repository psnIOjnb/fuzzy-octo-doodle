//
//  RegulatorCatalog.swift
//  OTC Pulse
//
//  Static catalog of regulators seeded into SwiftData on first launch.
//  Coordinates are approximate HQ locations used by the heatmap.
//

import Foundation

struct RegulatorSeed: Sendable {
    let code: String
    let name: String
    let region: Region
    let country: String
    let lat: Double
    let lon: Double
}

enum RegulatorCatalog {
    static let all: [RegulatorSeed] = [
        // Americas
        .init(code: "CFTC",  name: "Commodity Futures Trading Commission", region: .americas, country: "United States", lat: 38.90, lon: -77.03),
        .init(code: "SEC",   name: "Securities and Exchange Commission", region: .americas, country: "United States", lat: 38.89, lon: -77.01),
        .init(code: "FRB",   name: "Federal Reserve Board", region: .americas, country: "United States", lat: 38.89, lon: -77.04),
        .init(code: "OCC",   name: "Office of the Comptroller of the Currency", region: .americas, country: "United States", lat: 38.90, lon: -77.02),
        .init(code: "FDIC",  name: "Federal Deposit Insurance Corporation", region: .americas, country: "United States", lat: 38.90, lon: -77.04),
        .init(code: "OSFI",  name: "Office of the Superintendent of Financial Institutions", region: .americas, country: "Canada", lat: 45.42, lon: -75.70),
        .init(code: "CVM",   name: "Comissão de Valores Mobiliários", region: .americas, country: "Brazil", lat: -22.90, lon: -43.17),
        .init(code: "CNBV",  name: "Comisión Nacional Bancaria y de Valores", region: .americas, country: "Mexico", lat: 19.43, lon: -99.13),

        // Europe
        .init(code: "ECB",   name: "European Central Bank", region: .europe, country: "Germany", lat: 50.11, lon: 8.70),
        .init(code: "ESMA",  name: "European Securities and Markets Authority", region: .europe, country: "France", lat: 48.85, lon: 2.35),
        .init(code: "EBA",   name: "European Banking Authority", region: .europe, country: "France", lat: 48.86, lon: 2.34),
        .init(code: "FCA",   name: "Financial Conduct Authority", region: .europe, country: "United Kingdom", lat: 51.52, lon: -0.07),
        .init(code: "BOE",   name: "Bank of England / PRA", region: .europe, country: "United Kingdom", lat: 51.51, lon: -0.09),
        .init(code: "BAFIN", name: "Bundesanstalt für Finanzdienstleistungsaufsicht", region: .europe, country: "Germany", lat: 50.11, lon: 8.68),
        .init(code: "AMF",   name: "Autorité des Marchés Financiers", region: .europe, country: "France", lat: 48.87, lon: 2.33),
        .init(code: "FINMA", name: "Swiss Financial Market Supervisory Authority", region: .europe, country: "Switzerland", lat: 46.95, lon: 7.45),

        // Asia-Pacific
        .init(code: "MAS",   name: "Monetary Authority of Singapore", region: .asiaPacific, country: "Singapore", lat: 1.28, lon: 103.85),
        .init(code: "ASIC",  name: "Australian Securities and Investments Commission", region: .asiaPacific, country: "Australia", lat: -33.87, lon: 151.21),
        .init(code: "HKMA",  name: "Hong Kong Monetary Authority", region: .asiaPacific, country: "Hong Kong", lat: 22.28, lon: 114.16),
        .init(code: "SFC",   name: "Securities and Futures Commission", region: .asiaPacific, country: "Hong Kong", lat: 22.28, lon: 114.17),
        .init(code: "JFSA",  name: "Japan Financial Services Agency", region: .asiaPacific, country: "Japan", lat: 35.67, lon: 139.75),
        .init(code: "SEBI",  name: "Securities and Exchange Board of India", region: .asiaPacific, country: "India", lat: 19.06, lon: 72.86),

        // Middle East & Africa
        .init(code: "DFSA",  name: "Dubai Financial Services Authority", region: .mea, country: "United Arab Emirates", lat: 25.21, lon: 55.28),
        .init(code: "SAMA",  name: "Saudi Central Bank", region: .mea, country: "Saudi Arabia", lat: 24.69, lon: 46.72),
        .init(code: "FSCA",  name: "Financial Sector Conduct Authority", region: .mea, country: "South Africa", lat: -25.75, lon: 28.23),

        // International bodies
        .init(code: "FSB",   name: "Financial Stability Board", region: .international, country: "Switzerland (Basel)", lat: 47.56, lon: 7.59),
        .init(code: "IOSCO", name: "International Organization of Securities Commissions", region: .international, country: "Spain (Madrid)", lat: 40.42, lon: -3.70),
        .init(code: "BCBS",  name: "Basel Committee on Banking Supervision", region: .international, country: "Switzerland (Basel)", lat: 47.55, lon: 7.58),
        .init(code: "CPMI",  name: "Committee on Payments and Market Infrastructures", region: .international, country: "Switzerland (Basel)", lat: 47.57, lon: 7.60),
    ]

    static func seed(code: String) -> RegulatorSeed? {
        all.first { $0.code == code }
    }
}
