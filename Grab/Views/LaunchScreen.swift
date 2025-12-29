//
//  LaunchScreen.swift
//  Grab
//
//  Custom launch screen with Grab logo.
//

import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            Image("GrabLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
        }
    }
}

#Preview {
    LaunchScreen()
}
