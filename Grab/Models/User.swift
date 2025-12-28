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
    var totalAreaM2: Double
    
    init(totalRuns: Int = 0, totalDistanceM: Double = 0, totalAreaM2: Double = 0) {
        self.totalRuns = totalRuns
        self.totalDistanceM = totalDistanceM
        self.totalAreaM2 = totalAreaM2
    }
    
    var totalDistanceKm: Double {
        totalDistanceM / 1000.0
    }
    
    var totalAreaKm2: Double {
        totalAreaM2 / 1_000_000.0
    }
}
