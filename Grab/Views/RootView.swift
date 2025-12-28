//
//  RootView.swift
//  Grab
//
//  Root view that handles auth state and shows login, username setup, or main app.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.isLoading {
                // Loading state
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                }
            } else if authService.isAuthenticated {
                // Fully authenticated - show main app
                MainTabView()
            } else if authService.needsUsername {
                // Signed in but needs username
                UsernameSetupView()
            } else {
                // Not signed in - show login
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.needsUsername)
    }
}

#Preview {
    RootView()
}
