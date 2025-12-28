//
//  MapView.swift
//  Grab
//
//  UIKit MapView wrapper with hex overlays.
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let hexes: [TerritoryHex]
    let currentUserId: UUID?
    let onHexTapped: (TerritoryHex) -> Void
    let onRegionChanged: (MKCoordinateRegion) -> Void
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.currentUserId = currentUserId
        context.coordinator.onHexTapped = onHexTapped
        context.coordinator.hexes = hexes
        
        // Update region if changed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.0001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
        
        updateOverlays(mapView: mapView, hexes: hexes)
    }
    
    private func updateOverlays(mapView: MKMapView, hexes: [TerritoryHex]) {
        // Remove all existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Add hex overlays
        for hex in hexes {
            if let boundary = H3Utils.hexBoundary(hex.hexId) {
                let overlay = HexagonOverlay(coordinates: boundary.coordinates, count: boundary.coordinates.count)
                overlay.hexId = hex.hexId
                overlay.ownerUserId = hex.ownerUserId
                overlay.isOwnedByCurrentUser = hex.ownerUserId == currentUserId
                mapView.addOverlay(overlay, level: .aboveLabels)
            }
        }
        
        // Group territories and add boundary overlays
        let groups = TerritoryGrouper.groupTerritories(hexes)
        for group in groups {
            if !group.boundaryCoordinates.isEmpty {
                var coords = group.boundaryCoordinates
                let boundaryOverlay = TerritoryBoundaryOverlay(coordinates: &coords, count: coords.count)
                boundaryOverlay.ownerUserId = group.ownerUserId
                boundaryOverlay.isOwnedByCurrentUser = group.ownerUserId == currentUserId
                boundaryOverlay.hexCount = group.hexCount
                mapView.addOverlay(boundaryOverlay, level: .aboveRoads)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            region: $region,
            currentUserId: currentUserId,
            hexes: hexes,
            onHexTapped: onHexTapped,
            onRegionChanged: onRegionChanged
        )
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        @Binding var region: MKCoordinateRegion
        var currentUserId: UUID?
        var hexes: [TerritoryHex]
        var onHexTapped: (TerritoryHex) -> Void
        var onRegionChanged: (MKCoordinateRegion) -> Void
        
        init(
            region: Binding<MKCoordinateRegion>,
            currentUserId: UUID?,
            hexes: [TerritoryHex],
            onHexTapped: @escaping (TerritoryHex) -> Void,
            onRegionChanged: @escaping (MKCoordinateRegion) -> Void
        ) {
            _region = region
            self.currentUserId = currentUserId
            self.hexes = hexes
            self.onHexTapped = onHexTapped
            self.onRegionChanged = onRegionChanged
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            region = mapView.region
            onRegionChanged(mapView.region)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let hexOverlay = overlay as? HexagonOverlay {
                let renderer = HexagonOverlayRenderer(polygon: hexOverlay)
                renderer.isOwnedByCurrentUser = hexOverlay.isOwnedByCurrentUser
                renderer.ownerUserId = hexOverlay.ownerUserId
                return renderer
            } else if let boundaryOverlay = overlay as? TerritoryBoundaryOverlay {
                let renderer = TerritoryBoundaryRenderer(polygon: boundaryOverlay)
                renderer.isOwnedByCurrentUser = boundaryOverlay.isOwnedByCurrentUser
                renderer.ownerUserId = boundaryOverlay.ownerUserId
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Find the hex at this coordinate
            let hexId = H3Utils.coordinateToHexId(coordinate)
            
            if let hex = hexes.first(where: { $0.hexId == hexId }) {
                onHexTapped(hex)
            }
        }
    }
}
