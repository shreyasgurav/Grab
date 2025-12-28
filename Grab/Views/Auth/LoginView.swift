//
//  LoginView.swift
//  Grab
//
//  Google Sign-In login screen.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "map.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Grab")
                            .font(.system(size: 42, weight: .bold))
                        
                        Text("Claim territory by running")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 22))
                            
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 27))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSigningIn)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
            
            // Loading overlay
            if isSigningIn {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
        }
    }
    
    private func signInWithGoogle() {
        isSigningIn = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

#Preview {
    LoginView()
}
