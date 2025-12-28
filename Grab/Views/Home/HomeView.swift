//
//  HomeView.swift
//  Grab
//
//  Main map screen showing territory overlays.
//

import SwiftUI
import MapKit

struct HomeView: View {
    @StateObject private var territoryService = TerritoryService.shared
    @StateObject private var locationService = LocationService.shared
    @StateObject private var authService = AuthService.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedHex: TerritoryHex?
    @State private var showBottomSheet = false
    @State private var hasInitialLocation = false
    
    var body: some View {
        ZStack {
            // Map
            MapView(
                region: $region,
                hexes: territoryService.visibleTerritory,
                currentUserId: authService.currentUser?.id,
                onHexTapped: { hex in
                    selectedHex = hex
                    showBottomSheet = true
                },
                onRegionChanged: { newRegion in
                    Task {
                        await territoryService.loadTerritory(for: newRegion)
                    }
                }
            )
            .ignoresSafeArea()
            .onAppear {
                locationService.startUpdatingLocation()
            }
            
            // Player stats overlay
            PlayerStatsOverlay(
                territories: territoryService.visibleTerritory,
                currentUserId: authService.currentUser?.id
            )
            
            // Control buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // Location button
                    Button {
                        centerOnUserLocation()
                    } label: {
                        Image(systemName: locationService.currentLocation != nil ? "location.fill" : "location")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
            
            // Loading indicator
            if territoryService.isLoading {
                VStack {
                    HStack {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 60)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showBottomSheet) {
            if let hex = selectedHex {
                TerritoryBottomSheet(
                    hex: hex,
                    isOwnedByCurrentUser: hex.ownerUserId == authService.currentUser?.id,
                    onDismiss: {
                        showBottomSheet = false
                    }
                )
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .task {
            // Request location permission
            locationService.requestPermission()
            
            // Start location updates immediately
            locationService.startUpdatingLocation()
            
            // Wait for location with timeout
            var attempts = 0
            while locationService.currentLocation == nil && attempts < 50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }
            
            if let location = locationService.currentLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                hasInitialLocation = true
                await territoryService.loadTerritory(for: region)
            } else {
                // Fallback to default location if GPS fails
                print("⚠️ Location not available, using default coordinates")
            }
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            if !hasInitialLocation, let location = newLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                hasInitialLocation = true
                Task {
                    await territoryService.loadTerritory(for: region)
                }
            }
        }
    }
    
    private func centerOnUserLocation() {
        // Request permission if not already granted
        if locationService.authStatus == .notDetermined {
            locationService.requestPermission()
        }
        
        // Start location updates
        locationService.startUpdatingLocation()
        
        // Wait a moment for location to update, then center
        Task {
            var attempts = 0
            while locationService.currentLocation == nil && attempts < 30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }
            
            if let location = locationService.currentLocation {
                withAnimation {
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
    
}

#Preview {
    HomeView()
}
