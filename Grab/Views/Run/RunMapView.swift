//
//  RunMapView.swift
//  Grab
//
//  Full-screen map showing live run path during tracking.
//

import SwiftUI
import MapKit

struct RunMapView: UIViewRepresentable {
    let path: [CLLocationCoordinate2D]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.mapType = .standard
        mapView.pointOfInterestFilter = .excludingAll
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Only update overlays if path has changed significantly
        let shouldUpdateOverlay = context.coordinator.lastPathCount != path.count
        
        if shouldUpdateOverlay {
            mapView.removeOverlays(mapView.overlays)
            
            if path.count > 1 {
                let polyline = MKPolyline(coordinates: path, count: path.count)
                mapView.addOverlay(polyline, level: .aboveRoads)
            }
            
            context.coordinator.lastPathCount = path.count
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var lastPathCount: Int = 0
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
