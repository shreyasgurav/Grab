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
        ZStack {
            Color.black.ignoresSafeArea()
            
            Group {
                if authService.isLoading {
                    // Loading state
                    VStack(spacing: 24) {
                        Image("GrabLogoNoBG")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .opacity(0.9)
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    .transition(.opacity)
                    .onAppear {
                        print("🟢 RootView: Showing loading state")
                        print("🟢 RootView: isLoading = \(authService.isLoading)")
                        print("🟢 RootView: isAuthenticated = \(authService.isAuthenticated)")
                        print("🟢 RootView: needsUsername = \(authService.needsUsername)")
                    }
                } else if authService.isAuthenticated {
                    // Fully authenticated - show main app
                    MainTabView()
                        .onAppear {
                            print("🟢 RootView: Showing MainTabView")
                        }
                } else if authService.needsUsername {
                    // Signed in but needs username
                    UsernameSetupView()
                        .onAppear {
                            print("🟢 RootView: Showing UsernameSetupView")
                        }
                } else {
                    // Not signed in - show login
                    LoginView()
                        .onAppear {
                            print("🟢 RootView: Showing LoginView")
                        }
                }
            }
        }
        .onAppear {
            print("🟢 RootView: View appeared")
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authService.needsUsername)
    }
}

#Preview {
    RootView()
}
