//
//  User.swift
//  Grab
//

import Foundation

struct User: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var username: String
    var avatarURL: String?
    let createdAt: Date
    
    init(id: UUID = UUID(), username: String, avatarURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}

struct UserStats: Codable, Sendable {
    var totalRuns: Int
    var totalDistanceM: Double
    var totalTerritoryKm2: Double
    var ownedHexCount: Int
    
    init(totalRuns: Int = 0, totalDistanceM: Double = 0, totalTerritoryKm2: Double = 0, ownedHexCount: Int = 0) {
        self.totalRuns = totalRuns
        self.totalDistanceM = totalDistanceM
        self.totalTerritoryKm2 = totalTerritoryKm2
        self.ownedHexCount = ownedHexCount
    }
    
    var totalDistanceKm: Double {
        totalDistanceM / 1000.0
    }
}
