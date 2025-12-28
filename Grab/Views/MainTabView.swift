//
//  MainTabView.swift
//  Grab
//
//  Main tab bar with 3 tabs: Home, Run, Profile.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "map.fill")
                }
                .tag(0)
            
            RunView()
                .tabItem {
                    Label("Run", systemImage: "figure.run")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
}
