//
//  TerritoryService.swift
//  Grab
//
//  Handles territory data loading and caching.
//

import Foundation
import CoreLocation
import Combine
import MapKit

@MainActor
class TerritoryService: ObservableObject {
    static let shared = TerritoryService()
    
    private let storage = LocalStorageService.shared
    
    @Published var visibleTerritory: [TerritoryHex] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private var lastViewport: MKMapRect?
    private var debounceTask: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Load Territory for Viewport
    
    func loadTerritory(for region: MKCoordinateRegion) async {
        // Debounce rapid requests
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            
            guard !Task.isCancelled else { return }
            
            await performLoad(for: region)
        }
    }
    
    private func performLoad(for region: MKCoordinateRegion) async {
        isLoading = true
        lastError = nil
        
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLng = region.center.longitude - region.span.longitudeDelta / 2
        let maxLng = region.center.longitude + region.span.longitudeDelta / 2
        
        let hexes = await storage.loadTerritoryInViewport(
            minLat: minLat, maxLat: maxLat,
            minLng: minLng, maxLng: maxLng
        )
        
        // Only update if changed
        if hexes != visibleTerritory {
            visibleTerritory = hexes
        }
        
        isLoading = false
    }
    
    // MARK: - Get All Territory
    
    func loadAllTerritory() async -> [TerritoryHex] {
        return await storage.loadTerritory()
    }
    
    // MARK: - Get User Territory
    
    func loadUserTerritory(userId: UUID) async -> [TerritoryHex] {
        return await storage.loadTerritory(forUser: userId)
    }
    
    // MARK: - Get Territory by Hex IDs
    
    func getTerritory(hexIds: [String]) async -> [TerritoryHex] {
        return await storage.loadTerritory(hexIds: hexIds)
    }
    
    // MARK: - Get Hex at Coordinate
    
    func getHex(at coordinate: CLLocationCoordinate2D) async -> TerritoryHex? {
        let hexId = H3Utils.coordinateToHexId(coordinate)
        let hexes = await storage.loadTerritory(hexIds: [hexId])
        return hexes.first
    }
    
    // MARK: - Refresh
    
    func refresh() async {
        visibleTerritory = await storage.loadTerritory()
    }
}
