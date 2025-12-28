//
//  MockPathGenerator.swift
//  Grab
//
//  Generates realistic mock running paths for testing.
//

import Foundation
import CoreLocation

struct MockPathGenerator {
    
    static func generateMockPaths(around center: CLLocationCoordinate2D, currentUserId: UUID) async {
        let storage = LocalStorageService.shared
        
        // Generate 5-8 mock running paths
        let pathCount = Int.random(in: 5...8)
        
        for i in 0..<pathCount {
            let isCurrentUser = i < 2 // First 2 are current user's
            let ownerId = isCurrentUser ? currentUserId : UUID()
            let username = isCurrentUser ? "You" : "Runner\(i)"
            
            // Generate a realistic running path
            let path = generateRealisticRunPath(around: center, index: i)
            let distance = calculatePathDistance(path)
            
            let territoryPath = TerritoryPath(
                runId: UUID(),
                ownerUserId: ownerId,
                claimedAt: Date().addingTimeInterval(-Double.random(in: 0...604800)), // Within last week
                distanceM: distance,
                path: path,
                ownerUsername: username
            )
            
            try? await storage.saveTerritoryPath(territoryPath)
        }
    }
    
    private static func generateRealisticRunPath(around center: CLLocationCoordinate2D, index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        
        // Different path patterns to simulate different running routes
        let patterns = [
            generateLoopPath,
            generateOutAndBackPath,
            generateSquarePath,
            generateCircularPath,
            generateZigzagPath
        ]
        
        let pattern = patterns[index % patterns.count]
        return pattern(center, index)
    }
    
    // Loop path - like running around a block
    private static func generateLoopPath(_ center: CLLocationCoordinate2D, _ index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        let radius = 0.002 + Double(index) * 0.0005 // ~200-400m
        let pointCount = 40
        
        // Offset the center slightly for variety
        let offsetLat = Double.random(in: -0.003...0.003)
        let offsetLng = Double.random(in: -0.003...0.003)
        let loopCenter = CLLocationCoordinate2D(
            latitude: center.latitude + offsetLat,
            longitude: center.longitude + offsetLng
        )
        
        for i in 0...pointCount {
            let angle = (Double(i) / Double(pointCount)) * 2 * .pi
            
            // Add some irregularity to simulate road following
            let radiusVariation = radius * (1 + Double.random(in: -0.1...0.1))
            
            let lat = loopCenter.latitude + radiusVariation * cos(angle)
            let lng = loopCenter.longitude + radiusVariation * sin(angle)
            
            points.append(PathPoint(latitude: lat, longitude: lng))
        }
        
        return points
    }
    
    // Out and back path - like running to a point and returning
    private static func generateOutAndBackPath(_ center: CLLocationCoordinate2D, _ index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        let distance = 0.004 + Double(index) * 0.001 // ~400-800m
        let angle = Double.random(in: 0...(2 * .pi))
        
        // Go out
        for i in 0...20 {
            let progress = Double(i) / 20.0
            let lat = center.latitude + distance * progress * cos(angle)
            let lng = center.longitude + distance * progress * sin(angle)
            
            // Add slight variation for road following
            let variation = 0.0001 * sin(Double(i) * 0.5)
            points.append(PathPoint(
                latitude: lat + variation,
                longitude: lng + variation
            ))
        }
        
        // Come back
        for i in (0...20).reversed() {
            let progress = Double(i) / 20.0
            let lat = center.latitude + distance * progress * cos(angle)
            let lng = center.longitude + distance * progress * sin(angle)
            
            // Slightly different path on return
            let variation = 0.0001 * cos(Double(i) * 0.5)
            points.append(PathPoint(
                latitude: lat - variation,
                longitude: lng - variation
            ))
        }
        
        return points
    }
    
    // Square path - like running around a rectangular block
    private static func generateSquarePath(_ center: CLLocationCoordinate2D, _ index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        let size = 0.002 + Double(index) * 0.0003
        
        let corners = [
            CLLocationCoordinate2D(latitude: center.latitude + size, longitude: center.longitude + size),
            CLLocationCoordinate2D(latitude: center.latitude + size, longitude: center.longitude - size),
            CLLocationCoordinate2D(latitude: center.latitude - size, longitude: center.longitude - size),
            CLLocationCoordinate2D(latitude: center.latitude - size, longitude: center.longitude + size),
            CLLocationCoordinate2D(latitude: center.latitude + size, longitude: center.longitude + size)
        ]
        
        // Interpolate between corners
        for i in 0..<corners.count - 1 {
            let start = corners[i]
            let end = corners[i + 1]
            
            for j in 0...10 {
                let progress = Double(j) / 10.0
                let lat = start.latitude + (end.latitude - start.latitude) * progress
                let lng = start.longitude + (end.longitude - start.longitude) * progress
                
                // Add small variations
                let noise = 0.00005 * Double.random(in: -1...1)
                points.append(PathPoint(latitude: lat + noise, longitude: lng + noise))
            }
        }
        
        return points
    }
    
    // Circular path - smooth circle
    private static func generateCircularPath(_ center: CLLocationCoordinate2D, _ index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        let radius = 0.0025 + Double(index) * 0.0004
        let pointCount = 50
        
        for i in 0...pointCount {
            let angle = (Double(i) / Double(pointCount)) * 2 * .pi
            let lat = center.latitude + radius * cos(angle)
            let lng = center.longitude + radius * sin(angle)
            points.append(PathPoint(latitude: lat, longitude: lng))
        }
        
        return points
    }
    
    // Zigzag path - like running through streets
    private static func generateZigzagPath(_ center: CLLocationCoordinate2D, _ index: Int) -> [PathPoint] {
        var points: [PathPoint] = []
        let segments = 6
        let segmentLength = 0.001
        
        var currentLat = center.latitude
        var currentLng = center.longitude
        var direction = 0.0
        
        for i in 0...segments {
            // Alternate directions
            direction += .pi / 2 + Double.random(in: -0.3...0.3)
            
            for j in 0...10 {
                let progress = Double(j) / 10.0
                currentLat += segmentLength * progress * cos(direction) / 10
                currentLng += segmentLength * progress * sin(direction) / 10
                points.append(PathPoint(latitude: currentLat, longitude: currentLng))
            }
        }
        
        // Return to start
        let returnPoints = Int.random(in: 15...25)
        for i in 0...returnPoints {
            let progress = Double(i) / Double(returnPoints)
            let lat = currentLat + (center.latitude - currentLat) * progress
            let lng = currentLng + (center.longitude - currentLng) * progress
            points.append(PathPoint(latitude: lat, longitude: lng))
        }
        
        return points
    }
    
    private static func calculatePathDistance(_ path: [PathPoint]) -> Double {
        var distance = 0.0
        
        for i in 1..<path.count {
            let loc1 = CLLocation(latitude: path[i-1].latitude, longitude: path[i-1].longitude)
            let loc2 = CLLocation(latitude: path[i].latitude, longitude: path[i].longitude)
            distance += loc1.distance(from: loc2)
        }
        
        return distance
    }
}
