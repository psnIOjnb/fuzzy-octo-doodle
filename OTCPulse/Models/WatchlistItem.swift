//
//  WatchlistItem.swift
//  OTC Pulse
//
//  A user-saved publication with an optional personal note.
//

import Foundation
import SwiftData

@Model
final class WatchlistItem {
    /// Mirrors the publication's id so we can enforce one watchlist entry per publication.
    @Attribute(.unique) var publicationID: UUID
    var publication: Publication?
    var note: String?
    var dateAdded: Date

    init(publication: Publication, note: String? = nil, dateAdded: Date = .now) {
        self.publicationID = publication.id
        self.publication = publication
        self.note = note
        self.dateAdded = dateAdded
    }
}
