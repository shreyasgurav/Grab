//
//  PathSimplification.swift
//  Grab
//
//  Simplifies GPS paths using Douglas-Peucker algorithm to create smoother territory lines.
//

import Foundation
import CoreLocation

struct PathSimplification {
    
    /// Simplifies a path using the Douglas-Peucker algorithm
    /// - Parameters:
    ///   - points: Array of coordinates to simplify
    ///   - tolerance: Distance tolerance in meters (higher = more simplified)
    /// - Returns: Simplified array of coordinates
    static func simplify(points: [CLLocationCoordinate2D], tolerance: Double = 10.0) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        
        return douglasPeucker(points: points, epsilon: tolerance)
    }
    
    /// Douglas-Peucker path simplification algorithm
    private static func douglasPeucker(points: [CLLocationCoordinate2D], epsilon: Double) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }
        
        // Find the point with maximum distance from line between first and last
        var maxDistance = 0.0
        var maxIndex = 0
        let firstPoint = points.first!
        let lastPoint = points.last!
        
        for i in 1..<(points.count - 1) {
            let distance = perpendicularDistance(
                point: points[i],
                lineStart: firstPoint,
                lineEnd: lastPoint
            )
            
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If max distance is greater than epsilon, recursively simplify
        if maxDistance > epsilon {
            // Recursive call on both segments
            let leftSegment = douglasPeucker(
                points: Array(points[0...maxIndex]),
                epsilon: epsilon
            )
            let rightSegment = douglasPeucker(
                points: Array(points[maxIndex..<points.count]),
                epsilon: epsilon
            )
            
            // Combine results (remove duplicate middle point)
            return leftSegment.dropLast() + rightSegment
        } else {
            // All points between first and last can be removed
            return [firstPoint, lastPoint]
        }
    }
    
    /// Calculate perpendicular distance from point to line segment
    private static func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let x0 = point.latitude
        let y0 = point.longitude
        let x1 = lineStart.latitude
        let y1 = lineStart.longitude
        let x2 = lineEnd.latitude
        let y2 = lineEnd.longitude
        
        let dx = x2 - x1
        let dy = y2 - y1
        
        // Calculate perpendicular distance
        let numerator = abs(dy * x0 - dx * y0 + x2 * y1 - y2 * x1)
        let denominator = sqrt(dx * dx + dy * dy)
        
        guard denominator > 0 else {
            // Line start and end are the same point
            let location1 = CLLocation(latitude: x0, longitude: y0)
            let location2 = CLLocation(latitude: x1, longitude: y1)
            return location1.distance(from: location2)
        }
        
        return numerator / denominator * 111320.0 // Convert to meters (approximate)
    }
}
