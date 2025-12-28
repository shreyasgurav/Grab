//
//  AuthService.swift
//  Grab
//
//  Handles user authentication with Firebase Auth.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    private let firebaseService = FirebaseService.shared
    private let firestoreService = FirestoreService.shared
    private let storage = LocalStorageService.shared
    
    @Published var currentUser: User?
    @Published var firestoreUser: FirestoreUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var needsUsername = false
    @Published var authError: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                await self?.handleAuthStateChange(firebaseUser: firebaseUser)
            }
        }
    }
    
    private func handleAuthStateChange(firebaseUser: FirebaseAuth.User?) async {
        isLoading = true
        
        if let firebaseUser = firebaseUser {
            // User is signed in
            do {
                // Check if user exists in Firestore
                if let fsUser = try await firestoreService.getUser(userId: firebaseUser.uid) {
                    firestoreUser = fsUser
                    
                    if fsUser.hasUsername {
                        // User has username, fully authenticated
                        currentUser = User(
                            id: UUID(uuidString: firebaseUser.uid) ?? UUID(),
                            username: fsUser.username ?? "User",
                            avatarURL: fsUser.photoURL,
                            createdAt: fsUser.createdAt ?? Date()
                        )
                        isAuthenticated = true
                        needsUsername = false
                    } else {
                        // User exists but needs username
                        needsUsername = true
                        isAuthenticated = false
                    }
                } else {
                    // New user, create in Firestore
                    try await firestoreService.createUser(
                        userId: firebaseUser.uid,
                        email: firebaseUser.email,
                        displayName: firebaseUser.displayName,
                        photoURL: firebaseUser.photoURL?.absoluteString
                    )
                    
                    firestoreUser = try await firestoreService.getUser(userId: firebaseUser.uid)
                    needsUsername = true
                    isAuthenticated = false
                }
            } catch {
                authError = error.localizedDescription
                print("❌ Auth error: \(error.localizedDescription)")
            }
            
            isLoading = false
        } else {
            // User is signed out
            currentUser = nil
            firestoreUser = nil
            isAuthenticated = false
            needsUsername = false
            isLoading = false
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async throws {
        isLoading = true
        authError = nil
        
        do {
            let result = try await firebaseService.signInWithGoogle()
            
            // Auth state listener will handle the rest
            print("Signed in as: \(result.user.email ?? "unknown")")
        } catch {
            isLoading = false
            authError = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Set Username
    
    func setUsername(_ username: String) async throws {
        guard let firebaseUser = Auth.auth().currentUser else {
            throw FirebaseError.userNotAuthenticated
        }
        
        isLoading = true
        
        // Check if username is taken
        let exists = try await firestoreService.checkUsernameExists(username: username)
        if exists {
            isLoading = false
            throw UsernameError.alreadyTaken
        }
        
        // Update username in Firestore
        try await firestoreService.updateUsername(userId: firebaseUser.uid, username: username)
        
        // Update local state
        currentUser = User(
            id: UUID(uuidString: firebaseUser.uid) ?? UUID(),
            username: username,
            avatarURL: firebaseUser.photoURL?.absoluteString,
            createdAt: Date()
        )
        
        firestoreUser?.username = username
        isAuthenticated = true
        needsUsername = false
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        isLoading = true
        
        do {
            try firebaseService.signOut()
        } catch {
            authError = error.localizedDescription
        }
        
        currentUser = nil
        firestoreUser = nil
        isAuthenticated = false
        needsUsername = false
        isLoading = false
    }
    
    // MARK: - Get Firebase User ID
    
    var firebaseUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    // MARK: - Get User Stats
    
    func getUserStats() async -> UserStats {
        guard let fsUser = firestoreUser else {
            return UserStats()
        }
        
        return UserStats(
            totalRuns: fsUser.totalRuns,
            totalDistanceM: fsUser.totalDistanceM,
            totalAreaM2: fsUser.totalAreaM2
        )
    }
}

enum UsernameError: LocalizedError {
    case alreadyTaken
    case tooShort
    case invalid
    
    var errorDescription: String? {
        switch self {
        case .alreadyTaken: return "This username is already taken"
        case .tooShort: return "Username must be at least 3 characters"
        case .invalid: return "Username contains invalid characters"
        }
    }
}
