//
//  TerritoryBottomSheet.swift
//  Grab
//
//  Bottom sheet showing territory details when tapped.
//

import SwiftUI

struct TerritoryBottomSheet: View {
    let hex: TerritoryHex
    let isOwnedByCurrentUser: Bool
    let onDismiss: () -> Void
    
    private var ownerColor: Color {
        if let ownerId = hex.ownerUserId {
            return Color(TerritoryColorGenerator.color(for: ownerId))
        }
        return .gray
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
                    
                    Text(hex.ownerUsername?.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(ownerColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hex.ownerUsername ?? "Unclaimed")
                        .font(.system(size: 18, weight: .semibold))
                    
                    if isOwnedByCurrentUser {
                        Text("Your territory")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    } else if hex.ownerUserId != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                            Text("Run to steal")
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
                StatCard(
                    value: hex.claimedAt?.formatted(.dateTime.month(.abbreviated).day()) ?? "-",
                    label: "Claimed"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatCard(
                    value: String(format: "%.1f km", hex.lastRunDistanceKm ?? 0),
                    label: "Distance"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatCard(
                    value: String(format: "%.2f", H3Config.hexAreaKm2),
                    label: "km²"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct StatCard: View {
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

struct StatItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TerritoryBottomSheet(
        hex: TerritoryHex(
            hexId: "9_12345_67890",
            ownerUserId: UUID(),
            lastRunId: UUID(),
            claimedAt: Date(),
            lastRunDistanceM: 2500,
            ownerUsername: "Runner123"
        ),
        isOwnedByCurrentUser: false,
        onDismiss: {}
    )
}
