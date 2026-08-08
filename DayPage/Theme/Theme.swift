//
//  Theme.swift
//  DayPage
//
//  Design tokens: warm paper background, soft white cards, one blue accent,
//  a serif display face for headings and a monospaced face for the note.
//  Every colour is defined light-first with a dark counterpart, so the app
//  follows the system appearance without a second palette to maintain.
//

import SwiftUI
import UIKit

enum Theme {

    // MARK: Palette

    /// Page background — warm paper in light, near-black in dark.
    static let background = Color(light: 0xF4F2EF, dark: 0x0E0E10)
    /// Card surface.
    static let card = Color(light: 0xFFFFFF, dark: 0x1B1B1E)
    /// Slightly recessed surface used inside cards (the note sheet, chips).
    static let inset = Color(light: 0xF3F2F0, dark: 0x232327)
    /// Hairline borders and column dividers.
    static let stroke = Color(light: 0xE4E1DC, dark: 0x2E2E33)

    static let textPrimary = Color(light: 0x14141A, dark: 0xF2F2F5)
    static let textSecondary = Color(light: 0x6E6E78, dark: 0x9A9AA4)
    static let textTertiary = Color(light: 0x9B9BA4, dark: 0x6E6E78)

    /// Primary accent — the "Today" pill and the add button.
    static let accent = Color(light: 0x2F6BFF, dark: 0x5A8BFF)
    /// Overdue / destructive.
    static let overdue = Color(light: 0xD1372F, dark: 0xFF6B61)
    /// Completed state tick.
    static let done = Color(light: 0x2E9E6B, dark: 0x45C78E)

    /// Accent bar colours available per item.
    static let itemColors: [Color] = [
        Color(light: 0x2F6BFF, dark: 0x5A8BFF),   // blue
        Color(light: 0xD1372F, dark: 0xFF6B61),   // red
        Color(light: 0xC97A15, dark: 0xE8A33D),   // amber
        Color(light: 0x2E9E6B, dark: 0x45C78E),   // green
        Color(light: 0x7B4BD1, dark: 0xA47BF0),   // violet
        Color(light: 0x4A5568, dark: 0x8B93A3),   // slate
    ]

    static func itemColor(_ index: Int) -> Color {
        itemColors[((index % itemColors.count) + itemColors.count) % itemColors.count]
    }

    static let colorNames = ["Blue", "Red", "Amber", "Green", "Violet", "Slate"]

    // MARK: Type

    /// Page headline: "Sunday, 28 June".
    static let display = Font.system(.largeTitle, design: .serif).weight(.bold)
    /// Card titles: "Agenda", "Daily Note".
    static let cardTitle = Font.system(.title3, design: .serif).weight(.bold)
    /// Column captions: "ALL DAY + NO TIME".
    static let columnCaption = Font.system(.caption2).weight(.semibold)
    /// Agenda row title.
    static let rowTitle = Font.system(.subheadline).weight(.medium)
    /// Times and subtitles under a row.
    static let rowSubtitle = Font.system(.caption)
    /// The daily note itself.
    static let note = Font.system(.subheadline, design: .monospaced)

    // MARK: Metrics

    static let cardRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let pagePadding: CGFloat = 16
}

// MARK: - Colour helpers

extension Color {

    /// Hex convenience, e.g. `Color(hex: 0x2F6BFF)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// Appearance-aware colour built from two hex values. Resolves through
    /// `UIColor`, so it updates live when the user flips light/dark.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }
}
