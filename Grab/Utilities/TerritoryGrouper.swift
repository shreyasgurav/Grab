//
//  TerritoryGrouper.swift
//  Grab
//
//  Groups adjacent hexes into contiguous territories for outline rendering.
//

import Foundation
import CoreLocation

struct TerritoryGroup: Identifiable {
    let id = UUID()
    let ownerUserId: UUID
    let ownerUsername: String?
    let hexIds: Set<String>
    let boundaryCoordinates: [CLLocationCoordinate2D]
    
    var hexCount: Int {
        hexIds.count
    }
    
    var areaKm2: Double {
        H3Config.totalArea(hexCount: hexIds.count)
    }
}

struct TerritoryGrouper {
    
    /// Groups hexes by owner and finds contiguous territories
    static func groupTerritories(_ hexes: [TerritoryHex]) -> [TerritoryGroup] {
        var groups: [TerritoryGroup] = []
        
        // Group by owner
        let hexesByOwner = Dictionary(grouping: hexes.filter { $0.ownerUserId != nil }) { hex in
            hex.ownerUserId!
        }
        
        for (ownerId, ownerHexes) in hexesByOwner {
            // Find contiguous regions for this owner
            var unprocessed = Set(ownerHexes.map { $0.hexId })
            
            while !unprocessed.isEmpty {
                let startHexId = unprocessed.first!
                var region = Set<String>()
                var toProcess = [startHexId]
                
                // Flood fill to find connected hexes
                while let hexId = toProcess.popLast() {
                    guard unprocessed.contains(hexId) else { continue }
                    
                    region.insert(hexId)
                    unprocessed.remove(hexId)
                    
                    // Add adjacent hexes
                    let neighbors = getAdjacentHexIds(hexId)
                    for neighbor in neighbors {
                        if unprocessed.contains(neighbor) && !region.contains(neighbor) {
                            toProcess.append(neighbor)
                        }
                    }
                }
                
                // Create boundary for this region
                if !region.isEmpty {
                    let boundary = createBoundary(for: region)
                    let username = ownerHexes.first?.ownerUsername
                    
                    groups.append(TerritoryGroup(
                        ownerUserId: ownerId,
                        ownerUsername: username,
                        hexIds: region,
                        boundaryCoordinates: boundary
                    ))
                }
            }
        }
        
        return groups
    }
    
    /// Get adjacent hex IDs for a given hex
    private static func getAdjacentHexIds(_ hexId: String) -> [String] {
        let parts = hexId.split(separator: "_")
        guard parts.count == 3,
              let resolution = Int(parts[0]),
              let row = Int(parts[1]),
              let col = Int(parts[2]) else {
            return []
        }
        
        // Hexagonal grid neighbors (6 directions)
        let isEvenRow = row % 2 == 0
        let colOffset = isEvenRow ? 0 : 1
        
        let neighbors: [(Int, Int)] = [
            (row - 1, col - 1 + colOffset),  // Top-left
            (row - 1, col + colOffset),      // Top-right
            (row, col - 1),                  // Left
            (row, col + 1),                  // Right
            (row + 1, col - 1 + colOffset),  // Bottom-left
            (row + 1, col + colOffset)       // Bottom-right
        ]
        
        return neighbors.map { "\(resolution)_\($0.0)_\($0.1)" }
    }
    
    /// Create boundary polygon for a set of hexes
    private static func createBoundary(for hexIds: Set<String>) -> [CLLocationCoordinate2D] {
        var allPoints: [CLLocationCoordinate2D] = []
        
        // Get all hex boundaries
        for hexId in hexIds {
            if let boundary = H3Utils.hexBoundary(hexId) {
                allPoints.append(contentsOf: boundary.coordinates)
            }
        }
        
        guard !allPoints.isEmpty else { return [] }
        
        // Find convex hull or use center points
        // For simplicity, we'll use the bounding polygon
        let lats = allPoints.map { $0.latitude }
        let lngs = allPoints.map { $0.longitude }
        
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else {
            return []
        }
        
        // Create bounding box
        return [
            CLLocationCoordinate2D(latitude: minLat, longitude: minLng),
            CLLocationCoordinate2D(latitude: maxLat, longitude: minLng),
            CLLocationCoordinate2D(latitude: maxLat, longitude: maxLng),
            CLLocationCoordinate2D(latitude: minLat, longitude: maxLng),
            CLLocationCoordinate2D(latitude: minLat, longitude: minLng)
        ]
    }
}
