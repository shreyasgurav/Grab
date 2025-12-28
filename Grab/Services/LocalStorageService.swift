//
//  LocalStorageService.swift
//  Grab
//
//  Handles local data persistence using UserDefaults and file storage.
//

import Foundation
import CoreLocation

actor LocalStorageService {
    static let shared = LocalStorageService()
    
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private let userKey = "grab_current_user"
    private let runsKey = "grab_runs"
    private let territoryKey = "grab_territory"
    private let territoryPathsKey = "grab_territory_paths"
    private let statsKey = "grab_user_stats"
    
    private init() {}
    
    // MARK: - User
    
    func saveUser(_ user: User) throws {
        let data = try encoder.encode(user)
        userDefaults.set(data, forKey: userKey)
    }
    
    func loadUser() -> User? {
        guard let data = userDefaults.data(forKey: userKey) else { return nil }
        return try? decoder.decode(User.self, from: data)
    }
    
    func deleteUser() {
        userDefaults.removeObject(forKey: userKey)
    }
    
    // MARK: - Runs
    
    func saveRun(_ run: Run) throws {
        var runs = loadRuns()
        runs.append(run)
        let data = try encoder.encode(runs)
        userDefaults.set(data, forKey: runsKey)
    }
    
    func loadRuns() -> [Run] {
        guard let data = userDefaults.data(forKey: runsKey) else { return [] }
        return (try? decoder.decode([Run].self, from: data)) ?? []
    }
    
    func loadRuns(forUser userId: UUID) -> [Run] {
        loadRuns().filter { $0.userId == userId }
    }
    
    func deleteRuns() {
        userDefaults.removeObject(forKey: runsKey)
    }
    
    // MARK: - Territory
    
    func saveTerritory(_ hexes: [TerritoryHex]) throws {
        let data = try encoder.encode(hexes)
        userDefaults.set(data, forKey: territoryKey)
    }
    
    func updateTerritory(_ hex: TerritoryHex) throws {
        var hexes = loadTerritory()
        if let index = hexes.firstIndex(where: { $0.hexId == hex.hexId }) {
            hexes[index] = hex
        } else {
            hexes.append(hex)
        }
        try saveTerritory(hexes)
    }
    
    func updateTerritoryBatch(_ newHexes: [TerritoryHex]) throws {
        var hexes = loadTerritory()
        for newHex in newHexes {
            if let index = hexes.firstIndex(where: { $0.hexId == newHex.hexId }) {
                hexes[index] = newHex
            } else {
                hexes.append(newHex)
            }
        }
        try saveTerritory(hexes)
    }
    
    func loadTerritory() -> [TerritoryHex] {
        guard let data = userDefaults.data(forKey: territoryKey) else { return [] }
        return (try? decoder.decode([TerritoryHex].self, from: data)) ?? []
    }
    
    func loadTerritory(forUser userId: UUID) -> [TerritoryHex] {
        loadTerritory().filter { $0.ownerUserId == userId }
    }
    
    func loadTerritory(hexIds: [String]) -> [TerritoryHex] {
        let hexIdSet = Set(hexIds)
        return loadTerritory().filter { hexIdSet.contains($0.hexId) }
    }
    
    func loadTerritoryInViewport(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double) -> [TerritoryHex] {
        // Calculate viewport hex IDs without MainActor requirement
        let allTerritory = loadTerritory()
        return allTerritory.filter { hex in
            guard let center = H3Utils.hexIdToCenter(hex.hexId) else { return false }
            return center.latitude >= minLat && center.latitude <= maxLat &&
                   center.longitude >= minLng && center.longitude <= maxLng
        }
    }
    
    func deleteTerritory() {
        userDefaults.removeObject(forKey: territoryKey)
    }
    
    // MARK: - Territory Paths
    
    func saveTerritoryPath(_ path: TerritoryPath) throws {
        var paths = loadTerritoryPaths()
        paths.append(path)
        let data = try encoder.encode(paths)
        userDefaults.set(data, forKey: territoryPathsKey)
    }
    
    func loadTerritoryPaths() -> [TerritoryPath] {
        guard let data = userDefaults.data(forKey: territoryPathsKey) else { return [] }
        return (try? decoder.decode([TerritoryPath].self, from: data)) ?? []
    }
    
    func loadTerritoryPaths(forUser userId: UUID) -> [TerritoryPath] {
        loadTerritoryPaths().filter { $0.ownerUserId == userId }
    }
    
    func deleteTerritoryPaths() {
        userDefaults.removeObject(forKey: territoryPathsKey)
    }
    
    // MARK: - User Stats
    
    func saveStats(_ stats: UserStats, forUser userId: UUID) throws {
        var allStats = loadAllStats()
        allStats[userId.uuidString] = stats
        let data = try encoder.encode(allStats)
        userDefaults.set(data, forKey: statsKey)
    }
    
    func loadStats(forUser userId: UUID) -> UserStats {
        let allStats = loadAllStats()
        return allStats[userId.uuidString] ?? UserStats()
    }
    
    private func loadAllStats() -> [String: UserStats] {
        guard let data = userDefaults.data(forKey: statsKey) else { return [:] }
        return (try? decoder.decode([String: UserStats].self, from: data)) ?? [:]
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() {
        userDefaults.removeObject(forKey: userKey)
        userDefaults.removeObject(forKey: runsKey)
        userDefaults.removeObject(forKey: territoryKey)
        userDefaults.removeObject(forKey: statsKey)
    }
}
