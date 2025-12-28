//
//  TerritoryPathOverlay.swift
//  Grab
//
//  Overlay for displaying exact running paths as territories.
//

import MapKit
import UIKit

class TerritoryPathOverlay: MKPolyline {
    var runId: UUID?
    var ownerUserId: UUID?
    var isOwnedByCurrentUser: Bool = false
    var distanceM: Double = 0
}

class TerritoryPathRenderer: MKPolylineRenderer {
    private let ownerUserId: UUID?
    private let isOwnedByCurrentUser: Bool
    
    init(overlay: TerritoryPathOverlay) {
        self.ownerUserId = overlay.ownerUserId
        self.isOwnedByCurrentUser = overlay.isOwnedByCurrentUser
        super.init(overlay: overlay)
        
        self.lineCap = .round
        self.lineJoin = .round
        
        // Set color based on ownership - more subtle
        if isOwnedByCurrentUser {
            self.strokeColor = UIColor.systemBlue.withAlphaComponent(0.65)
        } else if let ownerId = ownerUserId {
            self.strokeColor = TerritoryColorGenerator.color(for: ownerId).withAlphaComponent(0.55)
        } else {
            self.strokeColor = UIColor.systemGray.withAlphaComponent(0.4)
        }
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Keep lines thin and consistent
        // Slightly thicker when zoomed in for better visibility
        if zoomScale > 2.0 {
            self.lineWidth = 3.5
        } else if zoomScale > 1.0 {
            self.lineWidth = 3.0
        } else {
            self.lineWidth = 2.5
        }
        
        // Always visible
        self.alpha = 1.0
        
        // Draw the path
        super.draw(mapRect, zoomScale: zoomScale, in: context)
    }
}
