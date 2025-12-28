//
//  TerritoryPathService.swift
//  Grab
//
//  Manages loading and caching of territory paths.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class TerritoryPathService: ObservableObject {
    static let shared = TerritoryPathService()
    
    private let storage = LocalStorageService.shared
    
    @Published var visiblePaths: [TerritoryPath] = []
    @Published var isLoading = false
    
    private init() {}
    
    func loadAllPaths() async {
        isLoading = true
        let paths = await storage.loadTerritoryPaths()
        visiblePaths = paths
        isLoading = false
    }
    
    func refresh() async {
        await loadAllPaths()
    }
}
