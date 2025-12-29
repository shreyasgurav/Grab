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
            // Black background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 20) {
                    Image("GrabLogoNoBG")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                    
                    VStack(spacing: 8) {
                        Text("Grab")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Claim territory by running")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Sign in button
                VStack(spacing: 16) {
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image("GoogleLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                            
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(white: 0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 27))
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
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
