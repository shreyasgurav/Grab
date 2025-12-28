//
//  OnboardingView.swift
//  Grab
//
//  Simple onboarding to create local user.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var authService = AuthService.shared
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo/Icon
            Image(systemName: "map.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.blue.gradient)
            
            // Title
            VStack(spacing: 8) {
                Text("Grab")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Claim your territory")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Username Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your username")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Username", text: $username)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 24)
            
            // Continue Button
            Button {
                createUser()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Get Started")
                        .font(.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(username.count >= 3 ? Color.blue : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(username.count < 3 || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    private func createUser() {
        guard username.count >= 3 else {
            errorMessage = "Username must be at least 3 characters"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.createLocalUser(username: username)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    OnboardingView()
}
