//
//  H3Utils.swift
//  Grab
//
//  Pure Swift H3-like hex grid implementation for territory representation.
//  Uses a simplified hexagonal grid system based on coordinate hashing.
//

import Foundation
import CoreLocation

struct H3Utils: Sendable {
    
    // Resolution 9 approximate hex size in degrees
    // Each hex is roughly 0.1 km² at this resolution
    private static let hexSizeDegrees: Double = 0.0009 // ~100m at equator
    private static let hexHeightRatio: Double = sqrt(3.0) / 2.0
    
    // MARK: - Coordinate to Hex ID
    
    static func coordinateToHexId(_ coordinate: CLLocationCoordinate2D, resolution: Int = H3Config.resolution) -> String {
        let scaleFactor = pow(3.0, Double(9 - resolution))
        let adjustedSize = hexSizeDegrees * scaleFactor
        
        // Offset rows for hexagonal packing
        let row = Int(floor(coordinate.latitude / (adjustedSize * hexHeightRatio)))
        let colOffset = (row % 2 == 0) ? 0.0 : (adjustedSize / 2.0)
        let col = Int(floor((coordinate.longitude + colOffset) / adjustedSize))
        
        return "\(resolution)_\(row)_\(col)"
    }
    
    // MARK: - Hex ID to Center Coordinate
    
    static func hexIdToCenter(_ hexId: String) -> CLLocationCoordinate2D? {
        let parts = hexId.split(separator: "_")
        guard parts.count == 3,
              let resolution = Int(parts[0]),
              let row = Int(parts[1]),
              let col = Int(parts[2]) else {
            return nil
        }
        
        let scaleFactor = pow(3.0, Double(9 - resolution))
        let adjustedSize = hexSizeDegrees * scaleFactor
        
        let colOffset = (row % 2 == 0) ? 0.0 : (adjustedSize / 2.0)
        let latitude = (Double(row) + 0.5) * adjustedSize * hexHeightRatio
        let longitude = (Double(col) + 0.5) * adjustedSize - colOffset
        
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // MARK: - Hex Boundary Vertices
    
    static func hexBoundary(_ hexId: String) -> HexBoundary? {
        guard let center = hexIdToCenter(hexId) else { return nil }
        
        let parts = hexId.split(separator: "_")
        guard let resolution = Int(parts[0]) else { return nil }
        
        let scaleFactor = pow(3.0, Double(9 - resolution))
        let size = hexSizeDegrees * scaleFactor * 0.5
        
        // Generate 6 vertices of hexagon
        var vertices: [CLLocationCoordinate2D] = []
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3.0 + .pi / 6.0
            let lat = center.latitude + size * hexHeightRatio * sin(angle)
            let lng = center.longitude + size * cos(angle)
            vertices.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        return HexBoundary(hexId: hexId, coordinates: vertices, center: center)
    }
    
    // MARK: - Polygon to Hex IDs (Fill polygon with hexes)
    
    static func polygonToHexIds(_ polygon: [CLLocationCoordinate2D], resolution: Int = H3Config.resolution) -> [String] {
        guard polygon.count >= 3 else { return [] }
        
        // Get bounding box
        let lats = polygon.map { $0.latitude }
        let lngs = polygon.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max() else { return [] }
        
        let scaleFactor = pow(3.0, Double(9 - resolution))
        let step = hexSizeDegrees * scaleFactor * 0.5
        
        var hexIds = Set<String>()
        
        // Sample points within bounding box
        var lat = minLat
        while lat <= maxLat {
            var lng = minLng
            while lng <= maxLng {
                let point = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                if isPointInPolygon(point, polygon: polygon) {
                    let hexId = coordinateToHexId(point, resolution: resolution)
                    hexIds.insert(hexId)
                }
                lng += step
            }
            lat += step
        }
        
        // Also include hexes for each vertex of the polygon
        for vertex in polygon {
            let hexId = coordinateToHexId(vertex, resolution: resolution)
            hexIds.insert(hexId)
        }
        
        return Array(hexIds)
    }
    
    // MARK: - Bounding Box to Hex IDs
    
    static func boundingBoxToHexIds(
        minLat: Double, maxLat: Double,
        minLng: Double, maxLng: Double,
        resolution: Int = H3Config.resolution
    ) -> [String] {
        let scaleFactor = pow(3.0, Double(9 - resolution))
        let step = hexSizeDegrees * scaleFactor
        
        var hexIds = Set<String>()
        
        var lat = minLat
        while lat <= maxLat {
            var lng = minLng
            while lng <= maxLng {
                let point = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let hexId = coordinateToHexId(point, resolution: resolution)
                hexIds.insert(hexId)
                lng += step
            }
            lat += step * hexHeightRatio
        }
        
        return Array(hexIds)
    }
    
    // MARK: - Point in Polygon (Ray Casting Algorithm)
    
    static func isPointInPolygon(_ point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude
            
            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)
            
            if intersect {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    // MARK: - Distance Calculation
    
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    // MARK: - Path to Polygon (Close the loop)
    
    static func pathToPolygon(_ path: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard path.count >= 3 else { return path }
        
        var polygon = path
        
        // Ensure the polygon is closed
        if let first = polygon.first, let last = polygon.last {
            let dist = distance(from: first, to: last)
            if dist > 1.0 { // More than 1 meter apart
                polygon.append(first)
            }
        }
        
        return polygon
    }
    
    // MARK: - Simplify Path (Douglas-Peucker)
    
    static func simplifyPath(_ path: [CLLocationCoordinate2D], tolerance: Double = 5.0) -> [CLLocationCoordinate2D] {
        guard path.count > 2 else { return path }
        
        var maxDistance: Double = 0
        var maxIndex = 0
        
        let first = path.first!
        let last = path.last!
        
        for i in 1..<path.count - 1 {
            let distance = perpendicularDistance(point: path[i], lineStart: first, lineEnd: last)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        if maxDistance > tolerance {
            let left = simplifyPath(Array(path[0...maxIndex]), tolerance: tolerance)
            let right = simplifyPath(Array(path[maxIndex...]), tolerance: tolerance)
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }
    
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude
        
        let lineLengthSquared = dx * dx + dy * dy
        
        if lineLengthSquared == 0 {
            return distance(from: point, to: lineStart)
        }
        
        var t = ((point.longitude - lineStart.longitude) * dx + (point.latitude - lineStart.latitude) * dy) / lineLengthSquared
        t = max(0, min(1, t))
        
        let projection = CLLocationCoordinate2D(
            latitude: lineStart.latitude + t * dy,
            longitude: lineStart.longitude + t * dx
        )
        
        return distance(from: point, to: projection)
    }
}
