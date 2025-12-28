//
//  AuthService.swift
//  Grab
//
//  Handles user authentication (local MVP - no backend auth).
//

import Foundation
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let storage = LocalStorageService.shared
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    
    private init() {
        Task {
            await loadUser()
        }
    }
    
    // MARK: - Load User
    
    func loadUser() async {
        isLoading = true
        currentUser = await storage.loadUser()
        isAuthenticated = currentUser != nil
        isLoading = false
    }
    
    // MARK: - Create Local User (MVP - no real auth)
    
    func createLocalUser(username: String) async throws {
        isLoading = true
        
        let user = User(
            id: UUID(),
            username: username,
            avatarURL: nil,
            createdAt: Date()
        )
        
        try await storage.saveUser(user)
        
        // Initialize empty stats
        try await storage.saveStats(UserStats(), forUser: user.id)
        
        currentUser = user
        isAuthenticated = true
        isLoading = false
    }
    
    // MARK: - Update User
    
    func updateUser(username: String? = nil, avatarURL: String? = nil) async throws {
        guard var user = currentUser else { return }
        
        if let username = username {
            user.username = username
        }
        if let avatarURL = avatarURL {
            user.avatarURL = avatarURL
        }
        
        try await storage.saveUser(user)
        currentUser = user
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        isLoading = true
        await storage.deleteUser()
        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }
    
    // MARK: - Delete Account (clears all data)
    
    func deleteAccount() async {
        isLoading = true
        await storage.clearAllData()
        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }
    
    // MARK: - Get User Stats
    
    func getUserStats() async -> UserStats {
        guard let userId = currentUser?.id else {
            return UserStats()
        }
        return await storage.loadStats(forUser: userId)
    }
}
