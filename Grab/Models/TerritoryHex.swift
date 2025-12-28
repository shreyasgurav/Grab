//
//  TerritoryHex.swift
//  Grab
//

import Foundation
import CoreLocation

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
