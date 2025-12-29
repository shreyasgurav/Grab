//
//  UsernameSetupView.swift
//  Grab
//
//  Username onboarding screen after first login.
//

import SwiftUI

struct UsernameSetupView: View {
    @StateObject private var authService = AuthService.shared
    @State private var username = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @FocusState private var isUsernameFocused: Bool
    
    private var isValidUsername: Bool {
        username.count >= 3 && username.count <= 20 &&
        username.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.blue.opacity(0.05), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose your username")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("This is how other runners will see you")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Username input
                VStack(spacing: 12) {
                    HStack {
                        Text("@")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        TextField("username", text: $username)
                            .font(.system(size: 20))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isUsernameFocused)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isUsernameFocused ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    
                    // Validation hints
                    HStack {
                        Image(systemName: isValidUsername ? "checkmark.circle.fill" : "info.circle")
                            .foregroundColor(isValidUsername ? .green : .secondary)
                        
                        Text("3-20 characters, letters, numbers, underscore")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                Spacer()
                
                // Continue button
                Button {
                    submitUsername()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(isValidUsername ? Color.blue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 27))
                    .shadow(color: isValidUsername ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!isValidUsername || isSubmitting)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isUsernameFocused = true
        }
    }
    
    private func submitUsername() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await authService.setUsername(username)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    UsernameSetupView()
}
