//
//  TerritoryPathService.swift
//  Grab
//
//  Manages loading territory paths from Firestore with local caching.
//

import Foundation
import CoreLocation
import Combine
import FirebaseFirestore

@MainActor
class TerritoryPathService: ObservableObject {
    static let shared = TerritoryPathService()
    
    private let storage = LocalStorageService.shared
    private let firestoreService = FirestoreService.shared
    
    @Published var visiblePaths: [TerritoryPath] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var listener: ListenerRegistration?
    
    private init() {}
    
    deinit {
        listener?.remove()
    }
    
    // Load all territories from Firestore
    func loadAllPaths() async {
        isLoading = true
        error = nil
        
        do {
            let firestoreTerritories = try await firestoreService.getAllTerritories(limit: 200)
            visiblePaths = firestoreTerritories.map { $0.toTerritoryPath() }
        } catch {
            self.error = error.localizedDescription
            // Fallback to local storage if Firestore fails
            let localPaths = await storage.loadTerritoryPaths()
            visiblePaths = localPaths
        }
        
        isLoading = false
    }
    
    // Load territories in a specific map region
    func loadPathsInRegion(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) async {
        isLoading = true
        error = nil
        
        do {
            let firestoreTerritories = try await firestoreService.getTerritoriesInRegion(
                minLat: minLat,
                maxLat: maxLat,
                minLng: minLng,
                maxLng: maxLng
            )
            visiblePaths = firestoreTerritories.map { $0.toTerritoryPath() }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Start realtime listener for territory updates
    func startRealtimeUpdates() {
        listener?.remove()
        
        listener = firestoreService.listenToTerritories { [weak self] territories in
            Task { @MainActor in
                self?.visiblePaths = territories.map { $0.toTerritoryPath() }
            }
        }
    }
    
    // Stop realtime updates
    func stopRealtimeUpdates() {
        listener?.remove()
        listener = nil
    }
    
    func refresh() async {
        await loadAllPaths()
    }
}
