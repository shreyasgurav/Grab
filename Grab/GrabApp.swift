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
        // Configure Firebase (must be on main thread)
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
