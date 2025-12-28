//
//  RunTrackingService.swift
//  Grab
//
//  Handles run tracking, validation, and loop detection.
//

import Foundation
import CoreLocation
import Combine

enum RunState {
    case idle
    case running
    case processing
    case completed(Run)
    case failed(String)
}

struct RunValidationConfig {
    static let minDistanceM: Double = 100 // Minimum 100m run
    static let minDurationS: Double = 30 // Minimum 30 seconds
    static let minPoints: Int = 10 // Minimum GPS points
    static let loopClosureThresholdM: Double = 50 // Start/end within 50m
    static let maxSpeedMs: Double = 12 // ~43 km/h (fast sprint + GPS drift margin)
    static let maxAccuracyM: Double = 50 // Ignore points with >50m accuracy
    static let maxTeleportM: Double = 200 // Max jump between consecutive points
}

@MainActor
class RunTrackingService: ObservableObject {
    static let shared = RunTrackingService()
    
    private let locationService = LocationService.shared
    private let storage = LocalStorageService.shared
    
    @Published var state: RunState = .idle
    @Published var currentPath: [GPSPoint] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var distanceM: Double = 0
    @Published var currentPace: String = "--:--"
    
    private var startTime: Date?
    private var timer: Timer?
    private var trackingTask: Task<Void, Never>?
    
    private init() {}
    
    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
    
    // MARK: - Start Run
    
    func startRun() {
        guard case .idle = state else { return }
        
        state = .running
        currentPath = []
        elapsedTime = 0
        distanceM = 0
        startTime = Date()
        
        // Start timer for elapsed time
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let start = self.startTime else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
                self.updatePace()
            }
        }
        
        // Start GPS tracking
        trackingTask = Task {
            let stream = locationService.startTracking()
            for await location in stream {
                await processLocation(location)
            }
        }
    }
    
    // MARK: - Stop Run
    
    func stopRun() async {
        guard case .running = state else { return }
        
        state = .processing
        timer?.invalidate()
        timer = nil
        trackingTask?.cancel()
        trackingTask = nil
        locationService.stopTracking()
        
        guard let startTime = startTime else {
            state = .failed("No start time recorded")
            return
        }
        
        let endTime = Date()
        
        // Process and validate the run
        do {
            let run = try await processRun(startTime: startTime, endTime: endTime)
            state = .completed(run)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        state = .idle
        currentPath = []
        elapsedTime = 0
        distanceM = 0
        currentPace = "--:--"
        startTime = nil
        timer?.invalidate()
        timer = nil
        trackingTask?.cancel()
        trackingTask = nil
    }
    
    // MARK: - Process Location
    
    private func processLocation(_ location: CLLocation) async {
        // Filter out low accuracy points
        guard location.horizontalAccuracy <= RunValidationConfig.maxAccuracyM else { return }
        
        let point = GPSPoint(location: location)
        
        // Check for teleport (unrealistic jump)
        if let lastPoint = currentPath.last {
            let distance = location.distance(from: CLLocation(
                latitude: lastPoint.latitude,
                longitude: lastPoint.longitude
            ))
            let timeDiff = location.timestamp.timeIntervalSince(lastPoint.timestamp)
            
            // Skip if teleport detected
            if distance > RunValidationConfig.maxTeleportM && timeDiff < 10 {
                return
            }
            
            // Skip if speed is unrealistic
            if timeDiff > 0 {
                let speed = distance / timeDiff
                if speed > RunValidationConfig.maxSpeedMs {
                    return
                }
            }
            
            // Update total distance
            distanceM += distance
        }
        
        currentPath.append(point)
    }
    
    private func updatePace() {
        guard distanceM > 0, elapsedTime > 0 else {
            currentPace = "--:--"
            return
        }
        
        let paceSecondsPerKm = elapsedTime / (distanceM / 1000.0)
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        currentPace = String(format: "%d:%02d /km", minutes, seconds)
    }
    
    // MARK: - Process Run (Validation + Territory Claim)
    
    private func processRun(startTime: Date, endTime: Date) async throws -> Run {
        guard let userId = await storage.loadUser()?.id else {
            throw RunError.noUser
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Validate run
        let validationResult = validateRun(
            path: currentPath,
            distanceM: distanceM,
            durationS: duration
        )
        
        var claimedHexIds: [String] = []
        
        if validationResult.isValid {
            // Convert path to polygon and claim territory
            let coordinates = currentPath.map { $0.coordinate }
            let simplifiedPath = H3Utils.simplifyPath(coordinates, tolerance: 10)
            let polygon = H3Utils.pathToPolygon(simplifiedPath)
            claimedHexIds = H3Utils.polygonToHexIds(polygon)
            
            // Claim territory
            if !claimedHexIds.isEmpty {
                try await claimTerritory(
                    hexIds: claimedHexIds,
                    userId: userId,
                    runId: UUID(),
                    distanceM: distanceM
                )
            }
        }
        
        let run = Run(
            userId: userId,
            startedAt: startTime,
            endedAt: endTime,
            distanceM: distanceM,
            durationS: duration,
            validLoop: validationResult.isValid,
            path: currentPath,
            claimedHexIds: claimedHexIds,
            invalidReason: validationResult.error?.rawValue
        )
        
        // Save run
        try await storage.saveRun(run)
        
        // Update user stats
        await updateUserStats(userId: userId, run: run, newHexCount: claimedHexIds.count)
        
        return run
    }
    
    // MARK: - Validation
    
    private func validateRun(path: [GPSPoint], distanceM: Double, durationS: Double) -> (isValid: Bool, error: RunValidationError?) {
        // Check minimum points
        guard path.count >= RunValidationConfig.minPoints else {
            return (false, .tooFewPoints)
        }
        
        // Check minimum distance
        guard distanceM >= RunValidationConfig.minDistanceM else {
            return (false, .tooShortDistance)
        }
        
        // Check minimum duration
        guard durationS >= RunValidationConfig.minDurationS else {
            return (false, .tooShortDuration)
        }
        
        // Check loop closure
        guard let first = path.first, let last = path.last else {
            return (false, .notALoop)
        }
        
        let closureDistance = H3Utils.distance(from: first.coordinate, to: last.coordinate)
        guard closureDistance <= RunValidationConfig.loopClosureThresholdM else {
            return (false, .notALoop)
        }
        
        // Check for speed anomalies
        for i in 1..<path.count {
            let prev = path[i - 1]
            let curr = path[i]
            let distance = H3Utils.distance(from: prev.coordinate, to: curr.coordinate)
            let timeDiff = curr.timestamp.timeIntervalSince(prev.timestamp)
            
            if timeDiff > 0 {
                let speed = distance / timeDiff
                if speed > RunValidationConfig.maxSpeedMs * 1.5 { // Allow some margin
                    return (false, .speedTooHigh)
                }
            }
        }
        
        return (true, nil)
    }
    
    // MARK: - Territory Claiming
    
    private func claimTerritory(hexIds: [String], userId: UUID, runId: UUID, distanceM: Double) async throws {
        let user = await storage.loadUser()
        
        var hexesToUpdate: [TerritoryHex] = []
        
        for hexId in hexIds {
            let hex = TerritoryHex(
                hexId: hexId,
                ownerUserId: userId,
                lastRunId: runId,
                claimedAt: Date(),
                lastRunDistanceM: distanceM,
                ownerUsername: user?.username,
                ownerAvatarURL: user?.avatarURL
            )
            hexesToUpdate.append(hex)
        }
        
        try await storage.updateTerritoryBatch(hexesToUpdate)
    }
    
    // MARK: - Update Stats
    
    private func updateUserStats(userId: UUID, run: Run, newHexCount: Int) async {
        var stats = await storage.loadStats(forUser: userId)
        stats.totalRuns += 1
        stats.totalDistanceM += run.distanceM
        
        if run.validLoop {
            // Recalculate owned territory
            let ownedHexes = await storage.loadTerritory(forUser: userId)
            stats.ownedHexCount = ownedHexes.count
            stats.totalTerritoryKm2 = H3Config.totalArea(hexCount: ownedHexes.count)
        }
        
        try? await storage.saveStats(stats, forUser: userId)
    }
}

enum RunError: LocalizedError {
    case noUser
    case invalidPath
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noUser: return "No user logged in"
        case .invalidPath: return "Invalid run path"
        case .saveFailed: return "Failed to save run"
        }
    }
}
