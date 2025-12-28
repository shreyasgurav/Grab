//
//  TerritoryPathOverlay.swift
//  Grab
//
//  Overlay for displaying filled territory areas with borders.
//

import MapKit
import UIKit

class TerritoryPathOverlay: MKPolygon {
    var runId: UUID?
    var ownerUserId: UUID?
    var isOwnedByCurrentUser: Bool = false
    var distanceM: Double = 0
}

class TerritoryPathRenderer: MKPolygonRenderer {
    private let ownerUserId: UUID?
    private let isOwnedByCurrentUser: Bool
    
    init(overlay: TerritoryPathOverlay) {
        self.ownerUserId = overlay.ownerUserId
        self.isOwnedByCurrentUser = overlay.isOwnedByCurrentUser
        super.init(overlay: overlay)
        
        self.lineCap = .round
        self.lineJoin = .round
        
        // Set colors based on ownership
        if isOwnedByCurrentUser {
            // Your territory: blue fill with darker border
            self.fillColor = UIColor.systemBlue.withAlphaComponent(0.25)
            self.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
        } else if let ownerId = ownerUserId {
            // Other player's territory: unique color with border
            let baseColor = TerritoryColorGenerator.color(for: ownerId)
            self.fillColor = baseColor.withAlphaComponent(0.2)
            self.strokeColor = baseColor.withAlphaComponent(0.7)
        } else {
            // Unclaimed: gray
            self.fillColor = UIColor.systemGray.withAlphaComponent(0.15)
            self.strokeColor = UIColor.systemGray.withAlphaComponent(0.5)
        }
        
        self.lineWidth = 3.0
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Adjust line width based on zoom - thinner when zoomed out
        if zoomScale > 3.0 {
            self.lineWidth = 2.5
        } else if zoomScale > 1.5 {
            self.lineWidth = 2.0
        } else if zoomScale > 0.5 {
            self.lineWidth = 1.5
        } else {
            self.lineWidth = 1.0
        }
        
        // Always visible
        self.alpha = 1.0
        
        // Draw the filled polygon with border
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}
