//
//  Theme.swift
//  OTC Pulse
//
//  Central design tokens for the dark fintech / intelligence-platform look:
//  deep navy + charcoal backgrounds, electric cyan accents, glassmorphism.
//

import SwiftUI

enum Theme {
    // MARK: Palette

    /// Deep navy base background (#0A0F1C).
    static let background = Color(hex: 0x0A0F1C)
    /// Slightly lifted navy surface (#0F1728).
    static let surface = Color(hex: 0x0F1728)
    /// Charcoal-navy for elevated layers (#141E33).
    static let surfaceElevated = Color(hex: 0x141E33)
    /// Electric cyan primary accent (#00F0FF).
    static let accent = Color(hex: 0x00F0FF)
    /// Softer electric blue for secondary emphasis (#3B82F6).
    static let accentBlue = Color(hex: 0x3B82F6)
    /// High-impact / alert red-orange (#FF4D6D).
    static let alert = Color(hex: 0xFF4D6D)
    /// Amber for medium impact / deadlines (#FFB020).
    static let warning = Color(hex: 0xFFB020)
    /// Positive green (#2DD4A8).
    static let positive = Color(hex: 0x2DD4A8)
    /// Primary text — near-white with a cold tint.
    static let textPrimary = Color(hex: 0xE8F0FF)
    /// Secondary, muted blue-grey text.
    static let textSecondary = Color(hex: 0x8B9BB8)
    /// Faint hairline / border color.
    static let hairline = Color(hex: 0x24314F)

    // MARK: Gradients

    /// Full-screen background: deep navy with a faint radial cyan glow up top.
    static var backgroundGradient: some View {
        ZStack {
            background.ignoresSafeArea()
            RadialGradient(
                colors: [accent.opacity(0.07), .clear],
                center: .init(x: 0.5, y: -0.15),
                startRadius: 10, endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    /// Signature accent gradient for emphasis strokes and numerals.
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentBlue],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Impact colors

    static func impactColor(_ score: Double) -> Color {
        switch score {
        case AppConfig.highImpactThreshold...: alert
        case 5.0..<AppConfig.highImpactThreshold: warning
        default: accent
        }
    }
}

extension Color {
    /// Convenience hex initializer, e.g. `Color(hex: 0x0A0F1C)`.
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Shared formatters

/// DateFormatter isn't Sendable, so the shared instances are confined to
/// the main actor — every caller (views, PDF export) already runs there.
@MainActor
enum Formatters {
    static let dayHeader: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func score(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
