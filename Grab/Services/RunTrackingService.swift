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
    private let firestoreService = FirestoreService.shared
    private let authService = AuthService.shared
    
    @Published var state: RunState = .idle
    @Published var currentPath: [GPSPoint] = []
    @Published var elapsedTime: TimeInterval = 0
    @Published var distanceM: Double = 0
    @Published var currentPace: String = "--:--"
    
    private var startTime: Date?
    private var timer: Timer?
    private var trackingTask: Task<Void, Never>?
    
    private init() {}
    
    // Helper to calculate pace string
    private func calculatePaceString(distanceM: Double, durationS: TimeInterval) -> String {
        guard distanceM > 0, durationS > 0 else { return "--:--" }
        let paceSecondsPerKm = durationS / (distanceM / 1000.0)
        let minutes = Int(paceSecondsPerKm) / 60
        let seconds = Int(paceSecondsPerKm) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
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
        // Get Firebase user ID first
        guard let firebaseUserId = authService.firebaseUserId else {
            print("❌ RunTrackingService: No Firebase user ID - user not authenticated")
            print("❌ RunTrackingService: isAuthenticated = \(authService.isAuthenticated)")
            print("❌ RunTrackingService: currentUser = \(String(describing: authService.currentUser))")
            throw RunError.noUser
        }
        
        print("🔵 RunTrackingService: Processing run for user: \(firebaseUserId)")
        
        // Use Firebase UID as the user ID
        guard let userId = UUID(uuidString: firebaseUserId) ?? authService.currentUser?.id else {
            print("❌ RunTrackingService: Failed to create UUID from Firebase user ID")
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
        let runId = UUID()
        
        if validationResult.isValid {
            // Simplify path to create smoother territory lines
            let rawPolygon = currentPath.map { $0.coordinate }
            let simplifiedPolygon = PathSimplification.simplify(points: rawPolygon, tolerance: 10.0)
            let username = authService.currentUser?.username ?? "Unknown"
            
            print("🔵 RunTrackingService: Simplified path from \(rawPolygon.count) to \(simplifiedPolygon.count) points")
            
            let firestoreTerritory = FirestoreTerritory(
                id: runId.uuidString,
                userId: firebaseUserId,
                username: username,
                polygon: simplifiedPolygon,
                distanceM: distanceM,
                claimedAt: Date(),
                colorSeed: firebaseUserId.hashValue
            )
            
            // Save to Firestore
            try await firestoreService.saveTerritory(firestoreTerritory)
            
            // Update user stats in Firestore
            let areaM2 = FirestoreTerritory.calculateArea(polygon: simplifiedPolygon)
            try await firestoreService.updateUserStats(
                userId: firebaseUserId,
                distanceM: distanceM,
                areaM2: areaM2
            )
        }
        
        // Save run to Firestore
        let avgPace = calculatePaceString(distanceM: distanceM, durationS: duration)
        let firestoreRun = FirestoreRun(
            id: runId.uuidString,
            userId: firebaseUserId,
            distanceM: distanceM,
            durationS: Int(duration),
            avgPace: avgPace,
            validated: validationResult.isValid,
            createdAt: Date()
        )
        try await firestoreService.saveRun(firestoreRun)
        
        // Create local run object for return
        let run = Run(
            id: runId,
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
        
        // Loop closure check removed - any path is valid as territory
        // Users can create territories from any run path, not just closed loops
        
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
    
    // MARK: - Update Stats (local fallback - main stats in Firestore)
    
    private func updateUserStats(userId: UUID, run: Run, newHexCount: Int) async {
        var stats = await storage.loadStats(forUser: userId)
        stats.totalRuns += 1
        stats.totalDistanceM += run.distanceM
        
        // Area is now calculated and stored in Firestore
        // Local stats are just a cache
        
        try? await storage.saveStats(stats, forUser: userId)
    }
}

enum RunError: LocalizedError {
    case noUser
    case invalidPath
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .noUser: return "Please sign in to save your run"
        case .invalidPath: return "Invalid run path"
        case .saveFailed: return "Failed to save run"
        }
    }
}
