//
//  PlayerStatsOverlay.swift
//  Grab
//
//  Shows player territory stats on the map.
//

import SwiftUI

struct PlayerStatsOverlay: View {
    let territories: [TerritoryHex]
    let currentUserId: UUID?
    
    private var topPlayers: [(userId: UUID, username: String, hexCount: Int, areaKm2: Double)] {
        let grouped = Dictionary(grouping: territories.filter { $0.ownerUserId != nil }) { $0.ownerUserId! }
        
        return grouped.map { userId, hexes in
            let username = hexes.first?.ownerUsername ?? "Unknown"
            let hexCount = hexes.count
            let areaKm2 = H3Config.totalArea(hexCount: hexCount)
            return (userId, username, hexCount, areaKm2)
        }
        .sorted { $0.hexCount > $1.hexCount }
        .prefix(5)
        .map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Territory Leaders")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ForEach(Array(topPlayers.enumerated()), id: \.offset) { index, player in
                        HStack(spacing: 8) {
                            // Rank badge
                            Text("\(index + 1)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(
                                    Circle()
                                        .fill(player.userId == currentUserId ? Color.blue : Color(UIColor.systemGray))
                                )
                            
                            // Color indicator
                            Circle()
                                .fill(Color(TerritoryColorGenerator.color(for: player.userId)))
                                .frame(width: 12, height: 12)
                            
                            // Player name
                            Text(player.username)
                                .font(.caption)
                                .fontWeight(player.userId == currentUserId ? .bold : .regular)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Area
                            Text(String(format: "%.2f km²", player.areaKm2))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .monospacedDigit()
                        }
                    }
                }
                .padding(12)
                
                Spacer()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.3))
                    )
            )
            .padding(.leading, 16)
            .padding(.top, 60)
            
            Spacer()
        }
    }
}

#Preview {
    PlayerStatsOverlay(
        territories: [],
        currentUserId: UUID()
    )
}
