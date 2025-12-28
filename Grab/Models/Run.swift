//
//  Run.swift
//  Grab
//

import Foundation
import CoreLocation

struct GPSPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.horizontalAccuracy = location.horizontalAccuracy
    }
    
    init(latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }
}

struct Run: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startedAt: Date
    let endedAt: Date
    let distanceM: Double
    let durationS: Double
    let validLoop: Bool
    let path: [GPSPoint]
    let claimedHexIds: [String]
    let createdAt: Date
    var invalidReason: String?
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        startedAt: Date,
        endedAt: Date,
        distanceM: Double,
        durationS: Double,
        validLoop: Bool,
        path: [GPSPoint],
        claimedHexIds: [String] = [],
        createdAt: Date = Date(),
        invalidReason: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceM = distanceM
        self.durationS = durationS
        self.validLoop = validLoop
        self.path = path
        self.claimedHexIds = claimedHexIds
        self.createdAt = createdAt
        self.invalidReason = invalidReason
    }
    
    var distanceKm: Double {
        distanceM / 1000.0
    }
    
    var formattedDuration: String {
        let hours = Int(durationS) / 3600
        let minutes = (Int(durationS) % 3600) / 60
        let seconds = Int(durationS) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var averagePacePerKm: String {
        guard distanceM > 0 else { return "--:--" }
        let paceSeconds = durationS / (distanceM / 1000.0)
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
}

enum RunValidationError: String, CaseIterable {
    case tooShortDistance = "Run distance too short (min 100m)"
    case tooShortDuration = "Run duration too short (min 30s)"
    case notALoop = "Run did not form a closed loop"
    case tooFewPoints = "Not enough GPS data points"
    case speedTooHigh = "Unrealistic speed detected"
    case poorAccuracy = "GPS accuracy too poor"
    case teleportDetected = "Location jump detected"
}
