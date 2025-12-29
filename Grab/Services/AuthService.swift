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
    @Published var isLoading = true
    @Published var needsUsername = false
    @Published var authError: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var hasInitialized = false
    
    private init() {
        print("🔵 AuthService: Initializing...")
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    
    private func setupAuthStateListener() {
        print("🔵 AuthService: Setting up auth state listener...")
        
        // Set up listener
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                print("🔵 AuthService: Auth state changed - user: \(firebaseUser?.email ?? "nil")")
                await self?.handleAuthStateChange(firebaseUser: firebaseUser)
            }
        }
        
        // Add timeout fallback - if auth doesn't respond in 3 seconds, show UI anyway
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if self.isLoading && !self.hasInitialized {
                print("⚠️ AuthService: Timeout - forcing initialization complete")
                self.isLoading = false
                self.hasInitialized = true
            }
        }
        
        // Check current user immediately
        let currentUser = Auth.auth().currentUser
        print("🔵 AuthService: Current user at init: \(currentUser?.email ?? "nil")")
        
        if currentUser == nil {
            Task { @MainActor in
                print("🔵 AuthService: No current user, setting isLoading = false")
                self.isLoading = false
                self.hasInitialized = true
            }
        }
    }
    
    private func handleAuthStateChange(firebaseUser: FirebaseAuth.User?) async {
        print("🔵 AuthService: handleAuthStateChange called")
        
        // Only set loading if we've already initialized
        if hasInitialized {
            isLoading = true
        }
        
        if let firebaseUser = firebaseUser {
            print("🔵 AuthService: User signed in: \(firebaseUser.email ?? "unknown")")
            // User is signed in
            do {
                // Check if user exists in Firestore
                if let fsUser = try await firestoreService.getUser(userId: firebaseUser.uid) {
                    print("🔵 AuthService: Found user in Firestore")
                    firestoreUser = fsUser
                    
                    if fsUser.hasUsername {
                        // User has username, fully authenticated
                        print("🔵 AuthService: User has username, fully authenticated")
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
                        print("🔵 AuthService: User needs username")
                        needsUsername = true
                        isAuthenticated = false
                    }
                } else {
                    // New user, create in Firestore
                    print("🔵 AuthService: Creating new user in Firestore")
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
            
            print("🔵 AuthService: Setting isLoading = false")
            isLoading = false
            hasInitialized = true
        } else {
            // User is signed out
            print("🔵 AuthService: No user signed in")
            currentUser = nil
            firestoreUser = nil
            isAuthenticated = false
            needsUsername = false
            isLoading = false
            hasInitialized = true
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
