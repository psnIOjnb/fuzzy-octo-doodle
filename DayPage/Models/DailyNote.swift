//
//  DailyNote.swift
//  DayPage
//
//  One free-text note per calendar day. Written in Markdown, stored as plain
//  text, rendered on demand — nothing here ever leaves the device.
//

import Foundation
import SwiftData

@Model
final class DailyNote {

    /// "yyyy-MM-dd" — unique so a day can never end up with two notes.
    @Attribute(.unique) var dayKey: String

    /// Midnight of the same day, kept for range queries and sorting.
    var day: Date
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(day: Date, text: String = "") {
        let start = Calendar.current.startOfDay(for: day)
        self.dayKey = DayKey.key(for: start)
        self.day = start
        self.text = text
        self.createdAt = .now
        self.updatedAt = .now
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
