//
//  Regulator.swift
//  OTC Pulse
//
//  Catalog of global financial regulators and international bodies.
//  Coordinates drive the world heatmap.
//

import Foundation
import SwiftData

@Model
final class Regulator {
    @Attribute(.unique) var code: String
    var name: String
    /// One of `Region.rawValue`.
    var region: String
    var country: String
    /// Approximate headquarters coordinates for heatmap placement.
    var latitude: Double
    var longitude: Double

    init(code: String, name: String, region: String, country: String,
         latitude: Double, longitude: Double) {
        self.code = code
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}
