//
//  QuickAddParser.swift
//  DayPage
//
//  Natural-language quick add: "Lunch with family at noon", "Standup every
//  weekday 9:15am", "Renew passport friday". Built on `NSDataDetector`, which
//  ships with the OS and runs entirely on-device.
//
//  The parse is deliberately conservative — whatever it cannot read stays in
//  the title, and the sheet shows exactly what it understood before saving.
//

import Foundation

struct ParsedEntry {
    var title: String
    /// Midnight of the day the entry belongs to.
    var day: Date
    /// Full date-time when a clock time was named, otherwise `nil`.
    var time: Date?
    var recurrence: Recurrence
    /// True when the text named a day other than the one on screen.
    var namedADay: Bool
}

@MainActor
enum QuickAddParser {

    /// Parses `input` for an entry being added to `day`.
    static func parse(_ input: String, on day: Date, now: Date = .now, calendar: Calendar = .current) -> ParsedEntry {
        let original = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var working = original

        let recurrence = extractRecurrence(from: &working)
        let (matchedDate, matchedText) = firstDate(in: working, referenceDate: now)

        var namedADay = false
        var time: Date?
        var resolvedDay = calendar.startOfDay(for: day)

        if let matchedDate, let matchedText {
            let saysDay = mentionsDay(matchedText)
            let saysTime = mentionsTime(matchedText)

            if saysDay {
                namedADay = true
                resolvedDay = calendar.startOfDay(for: matchedDate)
            }
            if saysTime {
                time = RecurrenceEngine.time(on: resolvedDay, likeThatOf: matchedDate, calendar: calendar)
            }
            // Only strip the phrase if we actually used it for something.
            if saysDay || saysTime {
                working = remove(matchedText, from: working)
            }
        }

        let title = tidy(working)
        return ParsedEntry(
            title: title.isEmpty ? original : title,
            day: resolvedDay,
            time: time,
            recurrence: recurrence,
            namedADay: namedADay
        )
    }

    // MARK: Recurrence

    /// Longest phrases first so "every other week" wins over "every week".
    private static let recurrencePhrases: [(pattern: String, rule: Recurrence)] = [
        (#"\bevery other week\b"#, .biweekly),
        (#"\bevery two weeks\b"#, .biweekly),
        (#"\bfortnightly\b"#, .biweekly),
        (#"\bevery weekday\b"#, .weekdays),
        (#"\bon weekdays\b"#, .weekdays),
        (#"\bevery day\b"#, .daily),
        (#"\beach day\b"#, .daily),
        (#"\bdaily\b"#, .daily),
        (#"\bevery week\b"#, .weekly),
        (#"\bweekly\b"#, .weekly),
        (#"\bevery month\b"#, .monthly),
        (#"\bmonthly\b"#, .monthly),
        (#"\bevery year\b"#, .yearly),
        (#"\byearly\b"#, .yearly),
        (#"\bannually\b"#, .yearly),
    ]

    /// "every monday" repeats weekly — the weekday itself is left in place so
    /// the date detector can still resolve which Monday to start from.
    private static let everyWeekdayPattern =
        #"\bevery\s+(?=(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)\b)"#

    private static func extractRecurrence(from text: inout String) -> Recurrence {
        for (pattern, rule) in recurrencePhrases {
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                text.removeSubrange(range)
                return rule
            }
        }
        if let range = text.range(of: everyWeekdayPattern, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
            return .weekly
        }
        return .none
    }

    // MARK: Dates

    private static func firstDate(in text: String, referenceDate: Date) -> (Date?, String?) {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        else { return (nil, nil) }

        let ns = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
        guard let match = matches.first, let date = match.date else { return (nil, nil) }
        return (date, ns.substring(with: match.range))
    }

    private static let timePattern =
        #"(\d{1,2}\s*[:.]\s*\d{2})|(\b\d{1,2}\s*(am|pm)\b)|\b(noon|midday|midnight|tonight)\b"#

    private static let dayPattern =
        #"\b(today|tomorrow|tomorow|yesterday|tonight|monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec|next|this|weekend)\b|\d{1,2}\s*(st|nd|rd|th)\b|\d{1,2}[/-]\d{1,2}"#

    private static func mentionsTime(_ text: String) -> Bool {
        text.range(of: timePattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func mentionsDay(_ text: String) -> Bool {
        text.range(of: dayPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: Title clean-up

    private static func remove(_ fragment: String, from text: String) -> String {
        guard let range = text.range(of: fragment) else { return text }
        return text.replacingCharacters(in: range, with: " ")
    }

    /// Drops the prepositions the date phrase left behind and squeezes
    /// whitespace, e.g. "Lunch with family at " → "Lunch with family".
    private static func tidy(_ text: String) -> String {
        var out = text.replacingOccurrences(
            of: #"\s+"#, with: " ", options: .regularExpression
        )
        for pattern in [#"\s+(at|on|from|by|@)\s*$"#, #"^\s*(at|on|from|by|@)\s+"#, #"\s+,"#] {
            out = out.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: " \t,-–—"))
    }
}
