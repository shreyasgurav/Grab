//
//  GrabApp.swift
//  Grab
//
//  Created by Shreyas Gurav on 28/12/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct GrabApp: App {
    
    init() {
        print("🟢 GrabApp: App initializing...")
        print("🟢 GrabApp: Device: \(UIDevice.current.name)")
        print("🟢 GrabApp: iOS: \(UIDevice.current.systemVersion)")
        
        // Configure Firebase (must be on main thread)
        let startTime = Date()
        do {
            print("🟢 GrabApp: Configuring Firebase...")
            FirebaseApp.configure()
            let duration = Date().timeIntervalSince(startTime)
            print("🟢 GrabApp: Firebase configured successfully in \(String(format: "%.2f", duration))s")
        } catch {
            print("❌ GrabApp: Firebase configuration failed: \(error)")
        }
        
        print("🟢 GrabApp: Init complete")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                
                RootView()
                    .preferredColorScheme(.dark)
                    .onOpenURL { url in
                        // Handle Google Sign-In callback
                        GIDSignIn.sharedInstance.handle(url)
                    }
            }
            .onAppear {
                print("🟢 GrabApp: WindowGroup appeared")
            }
        }
    }
}
