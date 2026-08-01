//
//  FeedDTO.swift
//  OTC Pulse
//
//  Codable wire format for the daily JSON feed. See Resources/sample-daily.json
//  for a worked example, and the README for how to host your own feed.
//

import Foundation

/// Top-level daily feed document: exactly the last 24 hours of publications.
struct DailyFeedDTO: Codable, Sendable {
    /// Calendar day the feed covers, "yyyy-MM-dd".
    let date: String
    /// When the feed file was generated (ISO 8601).
    let generatedAt: Date
    let publications: [PublicationDTO]
}

struct PublicationDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let summary: String
    let regulatorCode: String
    let regulatorName: String
    /// Must match one of the Region rawValues; unknown values fall back to "International Bodies".
    let region: String
    let publicationDate: Date
    let documentType: String
    let impactScore: Double
    let url: String?
    let tags: [String]
    let fullText: String?
    let deadline: DeadlineDTO?
}

struct DeadlineDTO: Codable, Sendable {
    let date: Date
    /// e.g. "Comments due", "Effective date", "Compliance deadline".
    let label: String
}

extension JSONDecoder {
    /// Decoder configured for the daily feed (ISO 8601 dates).
    static var feed: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
