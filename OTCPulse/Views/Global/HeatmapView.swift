//
//  HeatmapView.swift
//  OTC Pulse
//
//  Pure SwiftUI Canvas world heatmap. A coarse dot-matrix world silhouette
//  is drawn behind glowing, gently pulsing activity dots placed at
//  regulator HQ coordinates (equirectangular projection). Dot size and
//  glow scale with the day's publication count per location.
//

import SwiftUI

struct HeatPoint: Identifiable, Sendable {
    let id: String        // regulator code
    let latitude: Double
    let longitude: Double
    /// Number of publications at this location.
    let count: Int
    /// Highest impact score at this location (drives color).
    let maxImpact: Double
}

struct HeatmapView: View {
    let points: [HeatPoint]
    var height: CGFloat = 210

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                drawWorldDots(context: &context, size: size)

                for point in points {
                    let position = project(lat: point.latitude, lon: point.longitude, in: size)
                    // Slow pulse, desynchronized per point via a stable phase offset.
                    let phase = Double(point.id.hashValue % 628) / 100.0
                    let pulse = 0.75 + 0.25 * sin(t * 1.6 + phase)

                    let baseRadius = 3.0 + min(Double(point.count), 8.0) * 0.9
                    let color = point.maxImpact >= AppConfig.highImpactThreshold
                        ? Color(hex: 0xFF4D6D) : Color(hex: 0x00F0FF)

                    // Outer glow halos
                    for (multiplier, opacity) in [(3.2, 0.06), (2.2, 0.12), (1.5, 0.22)] {
                        let radius = baseRadius * multiplier * pulse
                        let rect = CGRect(x: position.x - radius, y: position.y - radius,
                                          width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
                    }
                    // Hot core
                    let core = CGRect(x: position.x - baseRadius / 2, y: position.y - baseRadius / 2,
                                      width: baseRadius, height: baseRadius)
                    context.fill(Path(ellipseIn: core), with: .color(color))
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Equirectangular lat/lon → view coordinates.
    private func project(lat: Double, lon: Double, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (lon + 180) / 360 * size.width,
            y: (90 - lat) / 180 * size.height * 1.28 - size.height * 0.10
        )
    }

    /// Coarse ASCII world silhouette: '#' cells become faint dots.
    /// 48 columns x 20 rows covering lat 90…-60 — enough to read as Earth.
    private static let worldGrid: [String] = [
        "................................................",
        "............##.....###..#######.###########....",
        "....######..###...###..########################",
        "..#########..##.....#..########################",
        ".##########......#####.#######################.",
        "..#########.....########..###################..",
        "...#######......########...#########..####.....",
        "....######.......#..#######..#######...##.#....",
        ".....#####...........#######.####.###..####....",
        "......###.............######..###...#..###.....",
        ".......##....#........######....#....####......",
        "........#...####.......#####.........###.##....",
        "............######......####.........#####.#...",
        "............#######......###..........##...#...",
        ".............######.......##..............##...",
        ".............#####.........#.........#####.....",
        "..............###..........#........#######....",
        "..............##....................#####.#....",
        "..............##.......................*...##..",
        "...............#...........................#...",
    ]

    private func drawWorldDots(context: inout GraphicsContext, size: CGSize) {
        let rows = Self.worldGrid.count
        let cellHeight = size.height / CGFloat(rows)

        for (rowIndex, row) in Self.worldGrid.enumerated() {
            let cols = row.count
            let cellWidth = size.width / CGFloat(cols)
            for (colIndex, char) in row.enumerated() where char == "#" {
                let rect = CGRect(
                    x: CGFloat(colIndex) * cellWidth + cellWidth * 0.3,
                    y: CGFloat(rowIndex) * cellHeight + cellHeight * 0.3,
                    width: cellWidth * 0.4,
                    height: cellHeight * 0.4
                )
                context.fill(Path(ellipseIn: rect),
                             with: .color(Color(hex: 0x3B82F6).opacity(0.22)))
            }
        }
    }
}

/// Convenience: build heat points from a set of publications by regulator.
@MainActor
func makeHeatPoints(from publications: [Publication]) -> [HeatPoint] {
    var byCode: [String: (count: Int, maxImpact: Double)] = [:]
    for pub in publications {
        var entry = byCode[pub.regulatorCode] ?? (0, 0)
        entry.count += 1
        entry.maxImpact = max(entry.maxImpact, pub.impactScore)
        byCode[pub.regulatorCode] = entry
    }
    return byCode.compactMap { code, stats in
        guard let seed = RegulatorCatalog.seed(code: code) else { return nil }
        return HeatPoint(id: code, latitude: seed.lat, longitude: seed.lon,
                         count: stats.count, maxImpact: stats.maxImpact)
    }
}
