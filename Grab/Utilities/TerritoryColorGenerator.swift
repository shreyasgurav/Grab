//
//  TerritoryColorGenerator.swift
//  Grab
//
//  Generates consistent colors for different territory owners.
//

import Foundation
import UIKit

struct TerritoryColorGenerator {
    
    // Vibrant color palette for different users
    private static let colorPalette: [UIColor] = [
        UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0),   // Blue
        UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0),   // Red
        UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0),   // Green
        UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),   // Orange
        UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0),   // Purple
        UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),   // Yellow
        UIColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1.0),   // Cyan
        UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1.0),   // Pink
        UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0),   // Brown
        UIColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1.0),   // Steel Blue
    ]
    
    /// Get a consistent color for a user ID
    static func color(for userId: UUID) -> UIColor {
        // Use UUID hash to consistently map to a color
        let hash = abs(userId.hashValue)
        let index = hash % colorPalette.count
        return colorPalette[index]
    }
    
    /// Get fill color with transparency for territory overlay
    static func fillColor(for userId: UUID, isCurrentUser: Bool) -> UIColor {
        if isCurrentUser {
            // Current user gets bright blue
            return UIColor.systemBlue.withAlphaComponent(0.35)
        } else {
            // Other users get their assigned color with transparency
            return color(for: userId).withAlphaComponent(0.25)
        }
    }
    
    /// Get stroke color for territory border
    static func strokeColor(for userId: UUID, isCurrentUser: Bool) -> UIColor {
        if isCurrentUser {
            return UIColor.systemBlue.withAlphaComponent(0.8)
        } else {
            return color(for: userId).withAlphaComponent(0.7)
        }
    }
}
