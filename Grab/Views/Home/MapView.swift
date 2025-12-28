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
    let paths: [TerritoryPath]
    let currentUserId: UUID?
    let onPathTapped: ((TerritoryPath) -> Void)?
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
        context.coordinator.onPathTapped = onPathTapped
        context.coordinator.paths = paths
        
        // Update region if changed
        if abs(mapView.region.center.latitude - region.center.latitude) > 0.0001 ||
           abs(mapView.region.center.longitude - region.center.longitude) > 0.0001 {
            mapView.setRegion(region, animated: true)
        }
        
        updateOverlays(mapView: mapView, paths: paths)
    }
    
    private func updateOverlays(mapView: MKMapView, paths: [TerritoryPath]) {
        // Remove all existing overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Add path overlays
        for path in paths {
            let coordinates = path.path.map { $0.coordinate }
            guard coordinates.count > 1 else { continue }
            
            let overlay = TerritoryPathOverlay(coordinates: coordinates, count: coordinates.count)
            overlay.runId = path.runId
            overlay.ownerUserId = path.ownerUserId
            overlay.isOwnedByCurrentUser = path.ownerUserId == currentUserId
            overlay.distanceM = path.distanceM
            mapView.addOverlay(overlay, level: .aboveRoads)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            currentUserId: currentUserId,
            onPathTapped: onPathTapped,
            paths: paths,
            onRegionChanged: onRegionChanged
        )
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var currentUserId: UUID?
        var onPathTapped: ((TerritoryPath) -> Void)?
        var paths: [TerritoryPath]
        var onRegionChanged: (MKCoordinateRegion) -> Void
        
        init(
            currentUserId: UUID?,
            onPathTapped: ((TerritoryPath) -> Void)?,
            paths: [TerritoryPath],
            onRegionChanged: @escaping (MKCoordinateRegion) -> Void
        ) {
            self.currentUserId = currentUserId
            self.onPathTapped = onPathTapped
            self.paths = paths
            self.onRegionChanged = onRegionChanged
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            onRegionChanged(mapView.region)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let pathOverlay = overlay as? TerritoryPathOverlay {
                return TerritoryPathRenderer(overlay: pathOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView,
                  let onPathTapped = onPathTapped else { return }
            
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Find closest path to tap location
            var closestPath: TerritoryPath?
            var minDistance = Double.infinity
            
            for path in paths {
                for pathPoint in path.path {
                    let location = CLLocation(latitude: pathPoint.latitude, longitude: pathPoint.longitude)
                    let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    let distance = location.distance(from: tapLocation)
                    
                    if distance < minDistance && distance < 50 { // Within 50m
                        minDistance = distance
                        closestPath = path
                    }
                }
            }
            
            if let path = closestPath {
                onPathTapped(path)
            }
        }
    }
}
