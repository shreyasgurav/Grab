//
//  RunView.swift
//  Grab
//
//  Run tracking screen with start/stop and live stats.
//

import SwiftUI
import MapKit

struct RunView: View {
    @StateObject private var runService = RunTrackingService.shared
    @StateObject private var locationService = LocationService.shared
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    
    var body: some View {
        ZStack {
            switch runService.state {
            case .idle:
                idleView
            case .running:
                runningView
            case .processing:
                processingView
            case .completed(let run):
                completedView(run: run)
            case .failed(let error):
                failedView(error: error)
            }
        }
        .onAppear {
            locationService.requestPermission()
            updateRegionToCurrentLocation()
        }
    }
    
    // MARK: - Idle State
    
    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
            
            // Instructions
            VStack(spacing: 8) {
                Text("Claim Territory")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Run a closed loop to claim the area inside.\nComplete the loop to own the territory.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // GPS Status
            gpsStatusView
            
            Spacer()
            
            // Start Button
            Button {
                runService.startRun()
            } label: {
                Text("START RUN")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        locationService.authStatus == .authorized
                            ? Color.blue
                            : Color.gray
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(locationService.authStatus != .authorized)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    private var gpsStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(gpsStatusColor)
                .frame(width: 8, height: 8)
            
            Text(gpsStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
    
    private var gpsStatusColor: Color {
        switch locationService.authStatus {
        case .authorized: return .green
        case .notDetermined: return .yellow
        case .denied, .restricted: return .red
        }
    }
    
    private var gpsStatusText: String {
        switch locationService.authStatus {
        case .authorized: return "GPS Ready"
        case .notDetermined: return "Location Permission Needed"
        case .denied: return "Location Access Denied"
        case .restricted: return "Location Restricted"
        }
    }
    
    // MARK: - Running State
    
    private var runningView: some View {
        ZStack {
            // Full-screen map with live path
            RunMapView(
                path: runService.currentPath.map { $0.coordinate },
                region: $region
            )
            .ignoresSafeArea()
            
            // Minimal stats overlay at top
            VStack {
                HStack(spacing: 16) {
                    // Time
                    VStack(spacing: 2) {
                        Text(formatTime(runService.elapsedTime))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("TIME")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Distance
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", runService.distanceM / 1000))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("KM")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    // Pace
                    VStack(spacing: 2) {
                        Text(runService.currentPace)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("PACE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .padding(.top, 60)
                
                Spacer()
            }
            
            // Stop button at bottom
            VStack {
                Spacer()
                
                Button {
                    Task {
                        await runService.stopRun()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24, weight: .bold))
                        Text("STOP")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 100)
            }
        }
        .onChange(of: locationService.currentLocation) { _, location in
            if let location = location {
                withAnimation(.easeInOut(duration: 0.3)) {
                    region.center = location.coordinate
                }
            }
        }
    }
    
    // MARK: - Processing State
    
    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Processing Run...")
                .font(.headline)
            
            Text("Validating and claiming territory")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Completed State
    
    private func completedView(run: Run) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Result Icon
            Image(systemName: run.validLoop ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(run.validLoop ? .green : .orange)
            
            // Title
            Text(run.validLoop ? "Territory Claimed!" : "Run Completed")
                .font(.title)
                .fontWeight(.bold)
            
            if !run.validLoop, let reason = run.invalidReason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Stats
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    StatBox(title: "Distance", value: String(format: "%.2f km", run.distanceKm))
                    StatBox(title: "Duration", value: run.formattedDuration)
                }
                
                if run.validLoop {
                    HStack(spacing: 32) {
                        StatBox(title: "Hexes Claimed", value: "\(run.claimedHexIds.count)")
                        StatBox(title: "Area", value: String(format: "%.3f km²", H3Config.totalArea(hexCount: run.claimedHexIds.count)))
                    }
                }
            }
            .padding(.vertical, 24)
            
            Spacer()
            
            // Done Button
            Button {
                runService.reset()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Failed State
    
    private func failedView(error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Run Failed")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Spacer()
            
            Button {
                runService.reset()
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func updateRegionToCurrentLocation() {
        if let location = locationService.currentLocation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    RunView()
}
