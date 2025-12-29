//
//  HomeView.swift
//  Grab
//
//  Main map screen showing territory overlays.
//

import SwiftUI
import MapKit

struct HomeView: View {
    @StateObject private var pathService = TerritoryPathService.shared
    @StateObject private var locationService = LocationService.shared
    @StateObject private var authService = AuthService.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var selectedPath: TerritoryPath?
    @State private var showBottomSheet = false
    @State private var hasInitialLocation = false
    
    var body: some View {
        ZStack {
            // Map
            MapView(
                region: $region,
                paths: pathService.visiblePaths,
                currentUserId: authService.currentUser?.id,
                onPathTapped: { path in
                    selectedPath = path
                    showBottomSheet = true
                },
                onRegionChanged: { _ in }
            )
            .ignoresSafeArea()
            .onAppear {
                locationService.startUpdatingLocation()
            }
            
            // Stats overlay showing run count
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(pathService.visiblePaths.count)")
                            .font(.system(size: 24, weight: .bold))
                        Text("Runs Claimed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                Spacer()
            }
            
            // Control buttons
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
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
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }
            }
            
            // Loading indicator
            if pathService.isLoading {
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
            if let path = selectedPath {
                TerritoryPathBottomSheet(
                    path: path,
                    isOwnedByCurrentUser: path.ownerUserId == authService.currentUser?.id,
                    onDismiss: { showBottomSheet = false }
                )
                .presentationDetents([.height(240)])
                .presentationDragIndicator(.hidden)
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .onAppear {
            // Request location permission immediately
            locationService.requestPermission()
        }
        .task {
            // Start location updates
            locationService.startUpdatingLocation()
            
            // Start realtime territory updates in background
            Task.detached(priority: .background) { @MainActor in
                self.pathService.startRealtimeUpdates()
            }
            
            // Don't block - show map immediately with default location
            // Location will update when available
            if let location = locationService.currentLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                hasInitialLocation = true
            }
        }
        .onDisappear {
            pathService.stopRealtimeUpdates()
        }
        .onChange(of: locationService.currentLocation) { newLocation in
            if !hasInitialLocation, let location = newLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                hasInitialLocation = true
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
    
    private func generateMockPaths() {
        guard let location = locationService.currentLocation,
              let userId = authService.currentUser?.id else { return }
        
        Task {
            await MockPathGenerator.generateMockPaths(
                around: location.coordinate,
                currentUserId: userId
            )
            await pathService.refresh()
        }
    }
    
}

#Preview {
    HomeView()
}
