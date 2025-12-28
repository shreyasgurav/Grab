//
//  TerritoryPathBottomSheet.swift
//  Grab
//
//  Bottom sheet showing path territory details when tapped.
//

import SwiftUI

struct TerritoryPathBottomSheet: View {
    let path: TerritoryPath
    let isOwnedByCurrentUser: Bool
    let onDismiss: () -> Void
    
    private var ownerColor: Color {
        return Color(TerritoryColorGenerator.color(for: path.ownerUserId))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            
            // Owner info
            HStack(spacing: 14) {
                // Avatar with owner color
                ZStack {
                    Circle()
                        .fill(ownerColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Text(path.ownerUsername?.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ownerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.ownerUsername ?? "Unknown Runner")
                        .font(.system(size: 18, weight: .semibold))
                    
                    if isOwnedByCurrentUser {
                        Text("Your run")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.run")
                                .font(.system(size: 11))
                            Text("Run this path to claim")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Stats row
            HStack(spacing: 0) {
                PathStatCard(
                    value: path.claimedAt.formatted(.dateTime.month(.abbreviated).day()),
                    label: "Claimed"
                )
                
                Divider()
                    .frame(height: 40)
                
                PathStatCard(
                    value: String(format: "%.2f km", path.distanceKm),
                    label: "Distance"
                )
                
                Divider()
                    .frame(height: 40)
                
                PathStatCard(
                    value: "\(path.path.count)",
                    label: "Points"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct PathStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
