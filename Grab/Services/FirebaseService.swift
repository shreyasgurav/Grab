//
//  FirebaseService.swift
//  Grab
//
//  Firebase configuration and initialization.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
class FirebaseService {
    static let shared = FirebaseService()
    
    let db: Firestore
    let auth: Auth
    
    private init() {
        // Configure Firebase if not already configured
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        
        self.db = Firestore.firestore()
        self.auth = Auth.auth()
        
        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        db.settings = settings
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() async throws -> AuthDataResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw FirebaseError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw FirebaseError.noRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw FirebaseError.missingIDToken
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        return try await auth.signIn(with: credential)
    }
    
    func signOut() throws {
        try auth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}

enum FirebaseError: LocalizedError {
    case missingClientID
    case noRootViewController
    case missingIDToken
    case userNotAuthenticated
    case documentNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingClientID: return "Firebase client ID not found"
        case .noRootViewController: return "No root view controller found"
        case .missingIDToken: return "Google ID token not found"
        case .userNotAuthenticated: return "User not authenticated"
        case .documentNotFound: return "Document not found"
        }
    }
}
