//
//  DailySnapshot.swift
//  OTC Pulse
//
//  One row per calendar day of ingested data — powers the Library tab
//  and gives an at-a-glance archive of every daily 24h snapshot.
//

import Foundation
import SwiftData

@Model
final class DailySnapshot {
    /// Canonical day key "yyyy-MM-dd" (UTC-agnostic, local calendar day).
    @Attribute(.unique) var dayKey: String
    /// Start of the calendar day this snapshot covers.
    var date: Date
    var totalCount: Int
    var highImpactCount: Int

    init(dayKey: String, date: Date, totalCount: Int, highImpactCount: Int) {
        self.dayKey = dayKey
        self.date = date
        self.totalCount = totalCount
        self.highImpactCount = highImpactCount
    }

    static func key(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }
}
