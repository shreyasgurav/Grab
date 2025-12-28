//
//  HexagonOverlay.swift
//  Grab
//
//  MapKit overlay for hexagonal territory display.
//

import Foundation
import MapKit

class HexagonOverlay: MKPolygon {
    var hexId: String = ""
    var ownerUserId: UUID?
    var isOwnedByCurrentUser: Bool = false
}

class HexagonOverlayRenderer: MKPolygonRenderer {
    var isOwnedByCurrentUser: Bool = false
    var ownerUserId: UUID?
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let path = self.path
        
        context.addPath(path!)
        
        if let ownerId = ownerUserId {
            let fillColor = TerritoryColorGenerator.fillColor(for: ownerId, isCurrentUser: isOwnedByCurrentUser)
            let strokeColor = TerritoryColorGenerator.strokeColor(for: ownerId, isCurrentUser: isOwnedByCurrentUser)
            
            context.setFillColor(fillColor.cgColor)
            context.setStrokeColor(strokeColor.cgColor)
        } else {
            // Fallback colors
            context.setFillColor(UIColor.systemGray.withAlphaComponent(0.2).cgColor)
            context.setStrokeColor(UIColor.systemGray.withAlphaComponent(0.5).cgColor)
        }
        
        context.setLineWidth(0.5 / zoomScale)
        context.drawPath(using: .fillStroke)
    }
}

// Territory boundary overlay for grouped territories
class TerritoryBoundaryOverlay: MKPolygon {
    var ownerUserId: UUID?
    var isOwnedByCurrentUser: Bool = false
    var hexCount: Int = 0
}

class TerritoryBoundaryRenderer: MKPolygonRenderer {
    var isOwnedByCurrentUser: Bool = false
    var ownerUserId: UUID?
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let path = self.path else { return }
        
        context.addPath(path)
        
        if let ownerId = ownerUserId {
            let strokeColor = TerritoryColorGenerator.strokeColor(for: ownerId, isCurrentUser: isOwnedByCurrentUser)
            context.setStrokeColor(strokeColor.cgColor)
        } else {
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        }
        
        // Thick border for territory boundaries
        context.setLineWidth(4.0 / zoomScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }
}
