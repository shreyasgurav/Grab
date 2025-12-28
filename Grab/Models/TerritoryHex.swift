//
//  TerritoryHex.swift
//  Grab
//

import Foundation
import CoreLocation

struct TerritoryPath: Codable, Identifiable, Equatable {
    var id: UUID { runId }
    let runId: UUID
    var ownerUserId: UUID
    var claimedAt: Date
    var distanceM: Double
    var path: [PathPoint]
    
    var ownerUsername: String?
    
    var distanceKm: Double {
        distanceM / 1000.0
    }
    
    init(
        runId: UUID,
        ownerUserId: UUID,
        claimedAt: Date,
        distanceM: Double,
        path: [PathPoint],
        ownerUsername: String? = nil
    ) {
        self.runId = runId
        self.ownerUserId = ownerUserId
        self.claimedAt = claimedAt
        self.distanceM = distanceM
        self.path = path
        self.ownerUsername = ownerUsername
    }
}

struct PathPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct TerritoryHex: Codable, Identifiable, Equatable {
    var id: String { hexId }
    let hexId: String
    var ownerUserId: UUID?
    var lastRunId: UUID?
    var claimedAt: Date?
    var lastRunDistanceM: Double?
    
    var ownerUsername: String?
    var ownerAvatarURL: String?
    
    var isOwned: Bool {
        ownerUserId != nil
    }
    
    var lastRunDistanceKm: Double? {
        guard let distanceM = lastRunDistanceM else { return nil }
        return distanceM / 1000.0
    }
    
    init(
        hexId: String,
        ownerUserId: UUID? = nil,
        lastRunId: UUID? = nil,
        claimedAt: Date? = nil,
        lastRunDistanceM: Double? = nil,
        ownerUsername: String? = nil,
        ownerAvatarURL: String? = nil
    ) {
        self.hexId = hexId
        self.ownerUserId = ownerUserId
        self.lastRunId = lastRunId
        self.claimedAt = claimedAt
        self.lastRunDistanceM = lastRunDistanceM
        self.ownerUsername = ownerUsername
        self.ownerAvatarURL = ownerAvatarURL
    }
}

struct HexBoundary: Equatable {
    let hexId: String
    let coordinates: [CLLocationCoordinate2D]
    let center: CLLocationCoordinate2D
    
    static func == (lhs: HexBoundary, rhs: HexBoundary) -> Bool {
        guard lhs.hexId == rhs.hexId,
              lhs.coordinates.count == rhs.coordinates.count else {
            return false
        }
        
        for (lCoord, rCoord) in zip(lhs.coordinates, rhs.coordinates) {
            if lCoord.latitude != rCoord.latitude || lCoord.longitude != rCoord.longitude {
                return false
            }
        }
        
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude
    }
}

// H3 Resolution 9: ~0.1 km² per hex (good for city-level play)
// Resolution 8: ~0.74 km² per hex
// Resolution 10: ~0.015 km² per hex
enum H3Config {
    static let resolution: Int = 9
    static let hexAreaKm2: Double = 0.1052 // Approximate area at resolution 9
    
    static func totalArea(hexCount: Int) -> Double {
        Double(hexCount) * hexAreaKm2
    }
}
