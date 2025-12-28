//
//  ProfileView.swift
//  Grab
//
//  User profile with stats and territory summary.
//

import SwiftUI
import MapKit

struct ProfileView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var territoryService = TerritoryService.shared
    
    @State private var stats = UserStats()
    @State private var ownedHexes: [TerritoryHex] = []
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Stats Grid
                    statsGrid
                    
                    // Territory Preview
                    territoryPreview
                    
                    // Actions
                    actionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadData()
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(authService.currentUser?.username.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.blue)
                )
            
            // Username
            Text(authService.currentUser?.username ?? "Unknown")
                .font(.title2)
                .fontWeight(.bold)
            
            // Joined date
            if let createdAt = authService.currentUser?.createdAt {
                Text("Joined \(createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Stats Grid
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
                .padding(.leading, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ProfileStatCard(
                    icon: "figure.run",
                    title: "Total Runs",
                    value: "\(stats.totalRuns)",
                    color: .blue
                )
                
                ProfileStatCard(
                    icon: "road.lanes",
                    title: "Distance",
                    value: String(format: "%.1f km", stats.totalDistanceKm),
                    color: .green
                )
                
                ProfileStatCard(
                    icon: "map.fill",
                    title: "Territory",
                    value: String(format: "%.3f km²", stats.totalAreaKm2),
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Territory Preview
    
    private var territoryPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Territory")
                .font(.headline)
                .padding(.leading, 4)
            
            if ownedHexes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No territory claimed yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Complete a run loop to claim your first territory!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                TerritoryMiniMap(hexes: ownedHexes)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .font(.body)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
    
    // MARK: - Load Data
    
    private func loadData() {
        Task {
            stats = await authService.getUserStats()
            if let userId = authService.currentUser?.id {
                ownedHexes = await territoryService.loadUserTerritory(userId: userId)
            }
        }
    }
}

struct ProfileStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TerritoryMiniMap: UIViewRepresentable {
    let hexes: [TerritoryHex]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        
        var allCoords: [CLLocationCoordinate2D] = []
        
        for hex in hexes {
            if let boundary = H3Utils.hexBoundary(hex.hexId) {
                let overlay = MKPolygon(coordinates: boundary.coordinates, count: boundary.coordinates.count)
                mapView.addOverlay(overlay)
                allCoords.append(contentsOf: boundary.coordinates)
            }
        }
        
        // Fit map to show all hexes
        if !allCoords.isEmpty {
            let lats = allCoords.map { $0.latitude }
            let lngs = allCoords.map { $0.longitude }
            
            if let minLat = lats.min(), let maxLat = lats.max(),
               let minLng = lngs.min(), let maxLng = lngs.max() {
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLng + maxLng) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) * 1.5 + 0.005,
                    longitudeDelta: (maxLng - minLng) * 1.5 + 0.005
                )
                mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: false)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.4)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

#Preview {
    ProfileView()
}
