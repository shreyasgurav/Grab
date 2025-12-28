//
//  FirestoreService.swift
//  Grab
//
//  Handles Firestore database operations for users and territories.
//

import Foundation
import FirebaseFirestore
import CoreLocation

@MainActor
class FirestoreService {
    static let shared = FirestoreService()
    
    private let db: Firestore
    
    // Collection references
    private var usersCollection: CollectionReference { db.collection("users") }
    private var territoriesCollection: CollectionReference { db.collection("territories") }
    private var runsCollection: CollectionReference { db.collection("runs") }
    
    private init() {
        self.db = FirebaseService.shared.db
    }
    
    // MARK: - User Operations
    
    func createUser(userId: String, email: String?, displayName: String?, photoURL: String?) async throws {
        let userData: [String: Any] = [
            "email": email ?? "",
            "displayName": displayName ?? "",
            "photoURL": photoURL ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "totalDistanceM": 0,
            "totalRuns": 0,
            "totalAreaM2": 0
        ]
        
        try await usersCollection.document(userId).setData(userData, merge: true)
    }
    
    func updateUsername(userId: String, username: String) async throws {
        try await usersCollection.document(userId).updateData([
            "username": username,
            "usernameUpdatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    func getUser(userId: String) async throws -> FirestoreUser? {
        let doc = try await usersCollection.document(userId).getDocument()
        guard doc.exists, let data = doc.data() else { return nil }
        return FirestoreUser(id: userId, data: data)
    }
    
    func checkUsernameExists(username: String) async throws -> Bool {
        let snapshot = try await usersCollection
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }
    
    func updateUserStats(userId: String, distanceM: Double, areaM2: Double) async throws {
        try await usersCollection.document(userId).updateData([
            "totalDistanceM": FieldValue.increment(distanceM),
            "totalRuns": FieldValue.increment(Int64(1)),
            "totalAreaM2": FieldValue.increment(areaM2)
        ])
    }
    
    // MARK: - Territory Operations
    
    func saveTerritory(_ territory: FirestoreTerritory) async throws {
        var data = territory.toFirestoreData()
        data["createdAt"] = FieldValue.serverTimestamp()
        
        try await territoriesCollection.document(territory.id).setData(data)
    }
    
    func getTerritoriesInRegion(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, limit: Int = 100) async throws -> [FirestoreTerritory] {
        // Query territories that overlap with the visible region
        // Using bounding box filtering
        let snapshot = try await territoriesCollection
            .whereField("bbox.maxLat", isGreaterThanOrEqualTo: minLat)
            .whereField("bbox.minLat", isLessThanOrEqualTo: maxLat)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FirestoreTerritory(id: doc.documentID, data: doc.data())
        }.filter { territory in
            // Additional client-side filtering for longitude
            territory.bbox.maxLng >= minLng && territory.bbox.minLng <= maxLng
        }
    }
    
    func getUserTerritories(userId: String) async throws -> [FirestoreTerritory] {
        let snapshot = try await territoriesCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "claimedAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FirestoreTerritory(id: doc.documentID, data: doc.data())
        }
    }
    
    func getAllTerritories(limit: Int = 200) async throws -> [FirestoreTerritory] {
        let snapshot = try await territoriesCollection
            .order(by: "claimedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FirestoreTerritory(id: doc.documentID, data: doc.data())
        }
    }
    
    // MARK: - Run Operations
    
    func saveRun(_ run: FirestoreRun) async throws {
        var data = run.toFirestoreData()
        data["createdAt"] = FieldValue.serverTimestamp()
        
        try await runsCollection.document(run.id).setData(data)
    }
    
    func getUserRuns(userId: String) async throws -> [FirestoreRun] {
        let snapshot = try await runsCollection
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            FirestoreRun(id: doc.documentID, data: doc.data())
        }
    }
    
    // MARK: - Realtime Listeners
    
    func listenToTerritories(completion: @escaping ([FirestoreTerritory]) -> Void) -> ListenerRegistration {
        return territoriesCollection
            .order(by: "claimedAt", descending: true)
            .limit(to: 200)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let territories = documents.compactMap { doc in
                    FirestoreTerritory(id: doc.documentID, data: doc.data())
                }
                completion(territories)
            }
    }
}

// MARK: - Firestore Models

struct FirestoreUser {
    let id: String
    var username: String?
    var email: String?
    var displayName: String?
    var photoURL: String?
    var createdAt: Date?
    var totalDistanceM: Double
    var totalRuns: Int
    var totalAreaM2: Double
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.username = data["username"] as? String
        self.email = data["email"] as? String
        self.displayName = data["displayName"] as? String
        self.photoURL = data["photoURL"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        self.totalDistanceM = data["totalDistanceM"] as? Double ?? 0
        self.totalRuns = data["totalRuns"] as? Int ?? 0
        self.totalAreaM2 = data["totalAreaM2"] as? Double ?? 0
    }
    
    var hasUsername: Bool {
        guard let username = username else { return false }
        return !username.isEmpty
    }
}

struct FirestoreTerritory {
    let id: String
    let userId: String
    let username: String
    let polygon: [GeoPoint]
    let distanceM: Double
    let areaM2: Double
    let claimedAt: Date
    let bbox: BoundingBox
    let colorSeed: Int
    
    struct BoundingBox {
        let minLat: Double
        let maxLat: Double
        let minLng: Double
        let maxLng: Double
    }
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.username = data["username"] as? String ?? "Unknown"
        self.distanceM = data["distanceM"] as? Double ?? 0
        self.areaM2 = data["areaM2"] as? Double ?? 0
        self.claimedAt = (data["claimedAt"] as? Timestamp)?.dateValue() ?? Date()
        self.colorSeed = data["colorSeed"] as? Int ?? 0
        
        // Parse polygon
        if let polygonData = data["polygon"] as? [[String: Double]] {
            self.polygon = polygonData.compactMap { point in
                guard let lat = point["lat"], let lng = point["lng"] else { return nil }
                return GeoPoint(latitude: lat, longitude: lng)
            }
        } else {
            self.polygon = []
        }
        
        // Parse bbox
        if let bboxData = data["bbox"] as? [String: Double] {
            self.bbox = BoundingBox(
                minLat: bboxData["minLat"] ?? 0,
                maxLat: bboxData["maxLat"] ?? 0,
                minLng: bboxData["minLng"] ?? 0,
                maxLng: bboxData["maxLng"] ?? 0
            )
        } else {
            self.bbox = BoundingBox(minLat: 0, maxLat: 0, minLng: 0, maxLng: 0)
        }
    }
    
    init(id: String, userId: String, username: String, polygon: [CLLocationCoordinate2D], distanceM: Double, claimedAt: Date, colorSeed: Int) {
        self.id = id
        self.userId = userId
        self.username = username
        self.polygon = polygon.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
        self.distanceM = distanceM
        self.areaM2 = Self.calculateArea(polygon: polygon)
        self.claimedAt = claimedAt
        self.colorSeed = colorSeed
        
        // Calculate bbox
        let lats = polygon.map { $0.latitude }
        let lngs = polygon.map { $0.longitude }
        self.bbox = BoundingBox(
            minLat: lats.min() ?? 0,
            maxLat: lats.max() ?? 0,
            minLng: lngs.min() ?? 0,
            maxLng: lngs.max() ?? 0
        )
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "username": username,
            "polygon": polygon.map { ["lat": $0.latitude, "lng": $0.longitude] },
            "distanceM": distanceM,
            "areaM2": areaM2,
            "claimedAt": Timestamp(date: claimedAt),
            "colorSeed": colorSeed,
            "bbox": [
                "minLat": bbox.minLat,
                "maxLat": bbox.maxLat,
                "minLng": bbox.minLng,
                "maxLng": bbox.maxLng
            ]
        ]
    }
    
    // Calculate polygon area using Shoelace formula (approximate for small areas)
    static func calculateArea(polygon: [CLLocationCoordinate2D]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        
        var area: Double = 0
        let n = polygon.count
        
        for i in 0..<n {
            let j = (i + 1) % n
            area += polygon[i].longitude * polygon[j].latitude
            area -= polygon[j].longitude * polygon[i].latitude
        }
        
        // Convert to square meters (approximate)
        let avgLat = polygon.map { $0.latitude }.reduce(0, +) / Double(n)
        let metersPerDegreeLat = 111320.0
        let metersPerDegreeLng = 111320.0 * cos(avgLat * .pi / 180)
        
        return abs(area) / 2.0 * metersPerDegreeLat * metersPerDegreeLng
    }
    
    // Convert to TerritoryPath for local rendering
    func toTerritoryPath() -> TerritoryPath {
        return TerritoryPath(
            runId: UUID(uuidString: id) ?? UUID(),
            ownerUserId: UUID(uuidString: userId) ?? UUID(),
            claimedAt: claimedAt,
            distanceM: distanceM,
            path: polygon.map { PathPoint(latitude: $0.latitude, longitude: $0.longitude) },
            ownerUsername: username
        )
    }
}

struct FirestoreRun {
    let id: String
    let userId: String
    let distanceM: Double
    let durationS: Int
    let avgPace: String
    let validated: Bool
    let createdAt: Date
    
    init(id: String, data: [String: Any]) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.distanceM = data["distanceM"] as? Double ?? 0
        self.durationS = data["durationS"] as? Int ?? 0
        self.avgPace = data["avgPace"] as? String ?? "--:--"
        self.validated = data["validated"] as? Bool ?? false
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    }
    
    init(id: String, userId: String, distanceM: Double, durationS: Int, avgPace: String, validated: Bool, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.distanceM = distanceM
        self.durationS = durationS
        self.avgPace = avgPace
        self.validated = validated
        self.createdAt = createdAt
    }
    
    func toFirestoreData() -> [String: Any] {
        return [
            "userId": userId,
            "distanceM": distanceM,
            "durationS": durationS,
            "avgPace": avgPace,
            "validated": validated,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}
