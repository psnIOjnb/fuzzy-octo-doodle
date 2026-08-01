//
//  MockDataGenerator.swift
//  OTC Pulse
//
//  Produces realistic sample daily feeds so the app is fully usable
//  offline from first launch. Swap in a real feed URL in Settings when
//  you have one — the wire format is identical (DailyFeedDTO).
//

import Foundation

enum MockDataGenerator {

    /// Title templates per topic. `%@` is replaced with a scope fragment.
    private static let templates: [(topic: String, docType: String, titles: [String])] = [
        ("Margin", "Final Rule", [
            "Amendments to Uncleared Margin Requirements for Non-Centrally Cleared Derivatives",
            "Revised Initial Margin Model Approval Framework %@",
            "Margin Requirements for Uncleared Swaps: Threshold Recalibration",
        ]),
        ("CCP Risk", "Consultation Paper", [
            "Consultation on CCP Recovery and Resolution Toolkits %@",
            "Review of Central Counterparty Default Fund Sizing Standards",
            "Stress Testing Framework for Central Counterparties: Proposed Enhancements",
        ]),
        ("Trade Reporting", "Guidance", [
            "Updated Technical Standards for OTC Derivatives Trade Reporting %@",
            "UPI and UTI Implementation Guidance for Reporting Entities",
            "Data Quality Remediation Expectations for Trade Repositories",
        ]),
        ("Trading Venues", "Policy Statement", [
            "Framework for Derivatives Trading Obligation on Regulated Venues %@",
            "Review of Swap Execution Facility Registration Requirements",
            "Pre-Trade Transparency Waivers for Derivatives Markets",
        ]),
        ("Capital Requirements", "Final Rule", [
            "Capital Treatment of Cleared Derivatives Exposures %@",
            "Counterparty Credit Risk Framework: SA-CCR Refinements",
            "Output Floor Implementation for Derivatives Portfolios",
        ]),
        ("Cross-border", "Statement", [
            "Comparability Determination for Cross-Border Margin Regimes %@",
            "Equivalence Assessment of Third-Country CCP Supervision",
            "Deference Framework for Cross-Border Derivatives Activity",
        ]),
        ("Clearing Obligation", "Consultation Paper", [
            "Proposed Expansion of the Clearing Obligation to Additional IRS Classes",
            "Clearing Obligation Review Following Benchmark Transition %@",
            "Exemption Framework for Intragroup Transactions: Renewal",
        ]),
        ("Benchmarks", "Guidance", [
            "Supervisory Expectations for Fallback Provisions in Derivative Contracts",
            "Post-LIBOR Benchmark Robustness Review %@",
        ]),
        ("Crypto Derivatives", "Consultation Paper", [
            "Regulatory Perimeter for Crypto-Asset Derivatives %@",
            "Margin and Capital Treatment of Tokenised Derivative Exposures",
        ]),
        ("Position Limits", "Final Rule", [
            "Position Limits for Commodity Derivative Contracts: Amendments %@",
            "Exemptions from Position Limits for Bona Fide Hedging",
        ]),
        ("Market Conduct", "Enforcement Action", [
            "Enforcement Action for Swap Dealer Reporting Failures",
            "Penalty Notice: Benchmark Manipulation in Rates Derivatives %@",
        ]),
        ("Netting", "Guidance", [
            "Recognition of Close-Out Netting in Resolution Frameworks %@",
            "Netting Opinions and Collateral Enforceability Update",
        ]),
    ]

    private static let scopeFragments = [
        "for Phase Six Entities", "— Second Consultation", "and Implementation Timeline",
        "for Interest Rate Derivatives", "for FX Forwards and Swaps", "in Emerging Markets",
        "(Post-Implementation Review)", "for Small Financial Counterparties", "",
    ]

    private static let secondaryTags = [
        "IRS", "FX", "Credit Derivatives", "Equity Derivatives", "Commodities",
        "Buy-side", "Swap Dealers", "SA-CCR", "EMIR", "Dodd-Frank", "UMR",
    ]

    private static let deadlineLabels = [
        "Comments due", "Consultation closes", "Effective date", "Compliance deadline",
    ]

    /// Deterministic-enough summary text for a publication.
    private static func summary(topic: String, regulator: RegulatorSeed, docType: String) -> String {
        "\(regulator.name) (\(regulator.code)) has issued a \(docType.lowercased()) addressing \(topic.lowercased()) "
        + "in OTC derivatives markets. The document sets out the authority's analysis, the proposed or final "
        + "requirements, applicable transition arrangements, and the expected impact on in-scope counterparties. "
        + "Market participants should assess exposure, documentation and operational readiness against the stated timeline."
    }

    /// Build a full mock daily feed for the given calendar day.
    /// - Parameters:
    ///   - day: the calendar day the feed covers.
    ///   - seed: optional seed so historical days are stable across launches.
    static func makeDailyFeed(for day: Date, seed: UInt64? = nil) -> DailyFeedDTO {
        var rng: any RandomNumberGenerator
        if let seed { rng = SeededGenerator(seed: seed) } else { rng = SystemRandomNumberGenerator() }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let count = Int.random(in: 10...22, using: &rng)
        var pubs: [PublicationDTO] = []
        pubs.reserveCapacity(count)

        for _ in 0..<count {
            let template = templates.randomElement(using: &rng)!
            let regulator = RegulatorCatalog.all.randomElement(using: &rng)!
            var title = template.titles.randomElement(using: &rng)!
            if title.contains("%@") {
                let fragment = scopeFragments.randomElement(using: &rng)!
                title = title
                    .replacingOccurrences(of: "%@", with: fragment)
                    .replacingOccurrences(of: "  ", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            }

            // Publication timestamp somewhere within the covered 24 hours.
            let publishedAt = startOfDay.addingTimeInterval(Double(Int.random(in: 7...20, using: &rng)) * 3600
                                                            + Double(Int.random(in: 0..<60, using: &rng)) * 60)

            // Impact skews mid-range with a high-impact tail.
            let base = Double.random(in: 2.0...9.8, using: &rng)
            let impact = (base * 10).rounded() / 10

            var tags = [template.topic]
            if Bool.random(using: &rng) { tags.append(secondaryTags.randomElement(using: &rng)!) }
            if impact >= AppConfig.highImpactThreshold { tags.append("Priority") }

            // ~40% of documents carry an extracted compliance/consultation date.
            var deadline: DeadlineDTO? = nil
            if Int.random(in: 0..<10, using: &rng) < 4 {
                let daysAhead = Int.random(in: 14...180, using: &rng)
                deadline = DeadlineDTO(
                    date: calendar.date(byAdding: .day, value: daysAhead, to: startOfDay)!,
                    label: deadlineLabels.randomElement(using: &rng)!
                )
            }

            pubs.append(PublicationDTO(
                id: UUID(),
                title: title,
                summary: summary(topic: template.topic, regulator: regulator, docType: template.docType),
                regulatorCode: regulator.code,
                regulatorName: regulator.name,
                region: regulator.region.rawValue,
                publicationDate: publishedAt,
                documentType: template.docType,
                impactScore: impact,
                url: "https://example.org/\(regulator.code.lowercased())/\(UUID().uuidString.prefix(8))",
                tags: tags,
                fullText: nil,
                deadline: deadline
            ))
        }

        return DailyFeedDTO(
            date: DailySnapshot.key(for: startOfDay),
            generatedAt: .now,
            publications: pubs.sorted { $0.publicationDate > $1.publicationDate }
        )
    }

    /// Feeds for the previous `days` calendar days (excluding today),
    /// used to seed a believable searchable history on first launch.
    static func makeHistory(days: Int) -> [DailyFeedDTO] {
        let calendar = Calendar.current
        return (1...days).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: .now)!
            // FNV-1a over the day key: stable across launches (unlike hashValue),
            // so a regenerated history looks identical for the same dates.
            var seed: UInt64 = 0xcbf29ce484222325
            for byte in DailySnapshot.key(for: day).utf8 {
                seed = (seed ^ UInt64(byte)) &* 0x100000001b3
            }
            return makeDailyFeed(for: day, seed: seed)
        }
    }
}

/// Small deterministic RNG (SplitMix64) for stable historical mock data.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
