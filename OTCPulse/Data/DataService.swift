//
//  DataService.swift
//  OTC Pulse
//
//  Orchestrates the daily data flow:
//    1. Download (or mock-generate) the last-24h JSON feed.
//    2. Decode and merge into SwiftData with deduplication (by url or id).
//    3. Update the day's DailySnapshot for the Library archive.
//    4. Fire local notifications for newly-ingested high-impact items.
//
//  Once merged, everything works 100% offline.
//
//  The service is @MainActor (hence Sendable) and owns a reference to the
//  ModelContainer, so views can trigger refreshes from @Sendable closures
//  (e.g. .refreshable) without smuggling a ModelContext across actors.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class DataService {

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    // Observable UI state
    var isRefreshing = false
    var lastError: String?
    var lastRefresh: Date? {
        didSet { UserDefaults.standard.set(lastRefresh, forKey: AppConfig.lastRefreshKey) }
    }

    init(container: ModelContainer) {
        self.container = container
        lastRefresh = UserDefaults.standard.object(forKey: AppConfig.lastRefreshKey) as? Date
    }

    // MARK: - Bootstrap

    /// First-launch setup: seed the regulator catalog, generate 30 days of
    /// realistic history, then ingest today's feed (bundled sample JSON).
    func bootstrapIfNeeded() async {
        seedRegulatorsIfNeeded()

        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppConfig.didBootstrapKey) else {
            await refreshIfStale()
            return
        }

        // 30 days of accumulated history so Search/Library/Deadlines are alive.
        for feed in MockDataGenerator.makeHistory(days: 30) {
            merge(feed: feed, notify: false)
        }

        // Today's feed: prefer the bundled sample JSON (re-based to today) to
        // demonstrate the real decode path; fall back to the generator.
        if let feed = loadBundledSampleFeed(rebasedTo: .now) {
            merge(feed: feed, notify: false)
        } else {
            merge(feed: MockDataGenerator.makeDailyFeed(for: .now), notify: false)
        }

        try? context.save()
        defaults.set(true, forKey: AppConfig.didBootstrapKey)
        lastRefresh = .now
    }

    /// Seeds the static regulator catalog exactly once.
    private func seedRegulatorsIfNeeded() {
        let count = (try? context.fetchCount(FetchDescriptor<Regulator>())) ?? 0
        guard count == 0 else { return }
        for seed in RegulatorCatalog.all {
            context.insert(Regulator(
                code: seed.code, name: seed.name, region: seed.region.rawValue,
                country: seed.country, latitude: seed.lat, longitude: seed.lon
            ))
        }
        try? context.save()
    }

    // MARK: - Refresh

    /// Auto-refresh on foreground if the last refresh is older than 6 hours.
    func refreshIfStale() async {
        if let last = lastRefresh, Date.now.timeIntervalSince(last) < 6 * 3600 { return }
        await refresh()
    }

    /// Manual/pull-to-refresh entry point.
    ///
    /// If a feed URL is configured in Settings, downloads and decodes the
    /// daily JSON from it. Otherwise generates a fresh mock feed for today
    /// so the demo experience keeps producing new intel.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            let feed: DailyFeedDTO
            let urlString = UserDefaults.standard.string(forKey: AppConfig.feedURLKey) ?? ""

            if !urlString.isEmpty, let url = URL(string: urlString) {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                feed = try JSONDecoder.feed.decode(DailyFeedDTO.self, from: data)
            } else {
                // Demo mode: synthesize a fresh last-24h feed.
                feed = MockDataGenerator.makeDailyFeed(for: .now)
            }

            merge(feed: feed, notify: true)
            try context.save()
            lastRefresh = .now
        } catch {
            lastError = "Refresh failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Merge & dedupe

    /// Merges a decoded feed into the store. Records already present
    /// (matched by URL when available, otherwise by id) are skipped, so
    /// re-downloading the same feed is always safe.
    private func merge(feed: DailyFeedDTO, notify: Bool) {
        // Existing identity sets — fetched once per merge for O(1) lookups.
        let existing = (try? context.fetch(FetchDescriptor<Publication>())) ?? []
        var knownIDs = Set(existing.map(\.id))
        var knownURLs = Set(existing.compactMap(\.url))

        var newHighImpact: [Publication] = []
        var insertedByDay: [String: (total: Int, high: Int)] = [:]

        for dto in feed.publications {
            if knownIDs.contains(dto.id) { continue }
            if let url = dto.url, knownURLs.contains(url) { continue }

            let region = Region(rawValue: dto.region)?.rawValue ?? Region.international.rawValue
            let pub = Publication(
                id: dto.id,
                title: dto.title,
                summary: dto.summary,
                regulatorName: dto.regulatorName,
                regulatorCode: dto.regulatorCode,
                region: region,
                publicationDate: dto.publicationDate,
                ingestedDate: .now,
                documentType: dto.documentType,
                impactScore: dto.impactScore,
                url: dto.url,
                tags: dto.tags,
                fullText: dto.fullText,
                deadlineDate: dto.deadline?.date,
                deadlineLabel: dto.deadline?.label
            )
            context.insert(pub)
            knownIDs.insert(dto.id)
            if let url = dto.url { knownURLs.insert(url) }

            let dayKey = DailySnapshot.key(for: dto.publicationDate)
            var day = insertedByDay[dayKey] ?? (0, 0)
            day.total += 1
            if pub.isHighImpact { day.high += 1; newHighImpact.append(pub) }
            insertedByDay[dayKey] = day
        }

        // Update (or create) the per-day snapshot rows for the Library.
        for (dayKey, delta) in insertedByDay {
            updateSnapshot(dayKey: dayKey, delta: delta)
        }

        // Local alert for fresh high-impact intel.
        if notify, !newHighImpact.isEmpty,
           UserDefaults.standard.bool(forKey: AppConfig.notificationsEnabledKey) {
            NotificationManager.notifyHighImpact(items: newHighImpact.map(\.title))
        }
    }

    private func updateSnapshot(dayKey: String, delta: (total: Int, high: Int)) {
        var descriptor = FetchDescriptor<DailySnapshot>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        if let snapshot = try? context.fetch(descriptor).first {
            snapshot.totalCount += delta.total
            snapshot.highImpactCount += delta.high
        } else {
            // Reconstruct the day's start date from the key.
            let parts = dayKey.split(separator: "-").compactMap { Int($0) }
            var comps = DateComponents()
            if parts.count == 3 { comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2] }
            let date = Calendar.current.date(from: comps) ?? .now
            context.insert(DailySnapshot(
                dayKey: dayKey, date: date,
                totalCount: delta.total, highImpactCount: delta.high
            ))
        }
    }

    // MARK: - Bundled sample

    /// Loads Resources/sample-daily.json and shifts its dates onto `day`,
    /// so the bundled example is always "today" on first launch.
    private func loadBundledSampleFeed(rebasedTo day: Date) -> DailyFeedDTO? {
        guard let url = Bundle.main.url(forResource: "sample-daily", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let feed = try? JSONDecoder.feed.decode(DailyFeedDTO.self, from: data)
        else { return nil }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let rebased = feed.publications.map { dto in
            // Keep the original time-of-day, move onto the target day.
            let hour = calendar.component(.hour, from: dto.publicationDate)
            let minute = calendar.component(.minute, from: dto.publicationDate)
            let newDate = startOfDay.addingTimeInterval(Double(hour) * 3600 + Double(minute) * 60)
            var newDeadline: DeadlineDTO? = nil
            if let deadline = dto.deadline {
                // Preserve the deadline's distance from the original publication day.
                let distance = deadline.date.timeIntervalSince(calendar.startOfDay(for: dto.publicationDate))
                newDeadline = DeadlineDTO(date: startOfDay.addingTimeInterval(distance), label: deadline.label)
            }
            return PublicationDTO(
                id: dto.id, title: dto.title, summary: dto.summary,
                regulatorCode: dto.regulatorCode, regulatorName: dto.regulatorName,
                region: dto.region, publicationDate: newDate,
                documentType: dto.documentType, impactScore: dto.impactScore,
                url: dto.url, tags: dto.tags, fullText: dto.fullText,
                deadline: newDeadline
            )
        }
        return DailyFeedDTO(date: DailySnapshot.key(for: startOfDay), generatedAt: .now, publications: rebased)
    }

    // MARK: - Storage management

    /// Deletes every stored record (used by Settings → Storage).
    func eraseAllData() {
        try? context.delete(model: WatchlistItem.self)
        try? context.delete(model: Publication.self)
        try? context.delete(model: DailySnapshot.self)
        try? context.save()
        UserDefaults.standard.set(false, forKey: AppConfig.didBootstrapKey)
        lastRefresh = nil
    }

    /// Erases and re-seeds the demo dataset.
    func regenerateSampleData() async {
        eraseAllData()
        await bootstrapIfNeeded()
    }
}
