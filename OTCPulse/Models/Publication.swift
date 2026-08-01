//
//  Publication.swift
//  OTC Pulse
//
//  A single OTC-derivatives-related publication issued by a regulator.
//  Publications accumulate forever on-device — nothing is ever purged
//  automatically, so the full history stays searchable offline.
//

import Foundation
import SwiftData

@Model
final class Publication {
    /// Stable identifier from the upstream feed. Used for deduplication.
    @Attribute(.unique) var id: UUID

    var title: String
    var summary: String
    var regulatorName: String
    var regulatorCode: String
    /// One of `Region.rawValue` (Americas, Europe, Asia-Pacific, MEA, International Bodies).
    var region: String
    /// When the regulator published the document.
    var publicationDate: Date
    /// When this device ingested the record.
    var ingestedDate: Date
    /// e.g. Final Rule, Consultation Paper, Guidance, Speech, Enforcement Action…
    var documentType: String
    /// 0.0 – 10.0 relevance/impact score assigned by the feed.
    var impactScore: Double
    var url: String?
    var tags: [String]
    var isHighImpact: Bool
    var fullText: String?

    // Extracted compliance dates (optional — only when the feed detected one).
    /// e.g. consultation close date, effective date, compliance deadline.
    var deadlineDate: Date?
    /// Human label for the deadline, e.g. "Comments due", "Effective date".
    var deadlineLabel: String?

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        regulatorName: String,
        regulatorCode: String,
        region: String,
        publicationDate: Date,
        ingestedDate: Date = .now,
        documentType: String,
        impactScore: Double,
        url: String? = nil,
        tags: [String] = [],
        fullText: String? = nil,
        deadlineDate: Date? = nil,
        deadlineLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.regulatorName = regulatorName
        self.regulatorCode = regulatorCode
        self.region = region
        self.publicationDate = publicationDate
        self.ingestedDate = ingestedDate
        self.documentType = documentType
        self.impactScore = impactScore
        self.url = url
        self.tags = tags
        self.isHighImpact = impactScore >= AppConfig.highImpactThreshold
        self.fullText = fullText
        self.deadlineDate = deadlineDate
        self.deadlineLabel = deadlineLabel
    }
}

/// Global app constants.
enum AppConfig {
    /// Publications scoring at or above this value are flagged high-impact.
    static let highImpactThreshold: Double = 7.5
    /// UserDefaults key for the remote daily feed URL (empty = mock mode).
    static let feedURLKey = "feedURL"
    /// UserDefaults key for the last successful refresh timestamp.
    static let lastRefreshKey = "lastRefreshDate"
    /// UserDefaults key for high-impact local notifications opt-in.
    static let notificationsEnabledKey = "notificationsEnabled"
    /// UserDefaults key marking that first-launch seeding completed.
    static let didBootstrapKey = "didBootstrapV1"
}
