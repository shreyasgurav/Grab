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
        
        // Configure Firebase (must be on main thread)
        do {
            print("🟢 GrabApp: Configuring Firebase...")
            FirebaseApp.configure()
            print("🟢 GrabApp: Firebase configured successfully")
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
