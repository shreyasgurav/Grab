//
//  LocationService.swift
//  Grab
//
//  Handles GPS location tracking with CoreLocation.
//

import Foundation
import CoreLocation
import Combine

enum LocationAuthStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authStatus: LocationAuthStatus = .notDetermined
    @Published var isTracking = false
    @Published var trackingError: String?
    
    private var locationContinuation: AsyncStream<CLLocation>.Continuation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        updateAuthStatus()
    }
    
    private func updateAuthStatus() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            authStatus = .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            authStatus = .authorized
        case .denied:
            authStatus = .denied
        case .restricted:
            authStatus = .restricted
        @unknown default:
            authStatus = .notDetermined
        }
    }
    
    func requestPermission() {
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        guard authStatus == .authorized else {
            trackingError = "Location permission not granted"
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func startTracking() -> AsyncStream<CLLocation> {
        isTracking = true
        trackingError = nil
        
        // Start location updates first
        locationManager.startUpdatingLocation()
        
        return AsyncStream { continuation in
            self.locationContinuation = continuation
            
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stopTracking()
                }
            }
        }
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationContinuation?.finish()
        locationContinuation = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            
            // Filter out low-quality GPS points
            if location.horizontalAccuracy <= 50 {
                self.locationContinuation?.yield(location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.trackingError = error.localizedDescription
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.updateAuthStatus()
        }
    }
}
