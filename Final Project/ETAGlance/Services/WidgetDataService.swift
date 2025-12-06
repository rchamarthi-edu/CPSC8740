//
//  WidgetDataService.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/25/25.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Widget Data Models

struct WidgetData: Codable {
    let favorites: [WidgetFavoriteData]
    let lastUpdated: Date
}

struct WidgetFavoriteData: Codable {
    let name: String
    let icon: String
    let fastestMode: String
    let fastestTime: String
    let fastestTimeMinutes: Int
}

// MARK: - Widget Data Service

class WidgetDataService {
    // App Group identifier - configure in Xcode capabilities
    static let appGroupIdentifier = "group.com.ethaglance.shared"
    static let widgetDataKey = "widget_eta_data"
    
    // MARK: - Save Data for Widget
    
    static func saveWidgetData(favorites: [FavoriteLocation], etaResults: [UUID: [TransportMode: ETAResult]]) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ [Widget] Failed to access App Group UserDefaults")
            return
        }
        
        var widgetFavorites: [WidgetFavoriteData] = []
        
        // Process favorites in order (preserves list order from HomeView)
        for favorite in favorites {
            let etas = etaResults[favorite.id]
            
            // Find fastest ETA if available
            var fastestMode: TransportMode = favorite.transportModes.first ?? .automobile
            var fastestTime: Int = -1  // -1 indicates no data
            
            if let etas = etas {
                for (mode, result) in etas {
                    if let time = result.travelTimeMinutes {
                        if fastestTime == -1 || time < fastestTime {
                            fastestTime = time
                            fastestMode = mode
                        }
                    }
                }
            }
            
            let modeIdentifier = transportModeIdentifier(for: fastestMode)
            let timeString = fastestTime > 0 ? formatTime(minutes: fastestTime) : "--"
            
            let widgetFavorite = WidgetFavoriteData(
                name: favorite.name,
                icon: favorite.icon,
                fastestMode: modeIdentifier,
                fastestTime: timeString,
                fastestTimeMinutes: max(fastestTime, 0)
            )
            
            widgetFavorites.append(widgetFavorite)
        }
        
        let widgetData = WidgetData(favorites: widgetFavorites, lastUpdated: Date())
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(widgetData)
            sharedDefaults.set(data, forKey: widgetDataKey)
            sharedDefaults.synchronize()
            
            print("✅ [Widget] Saved \(widgetFavorites.count) favorites to App Group")
            
            // Trigger widget refresh
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            
        } catch {
            print("❌ [Widget] Failed to encode widget data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Data for Widget
    
    static func loadWidgetData() -> WidgetData? {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ [Widget] Failed to access App Group UserDefaults")
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: widgetDataKey) else {
            print("⚠️ [Widget] No widget data found")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode(WidgetData.self, from: data)
            print("✅ [Widget] Loaded \(widgetData.favorites.count) favorites from App Group")
            return widgetData
        } catch {
            print("❌ [Widget] Failed to decode widget data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private static func transportModeIdentifier(for mode: TransportMode) -> String {
        switch mode {
        case .automobile: return "automobile"
        case .walking: return "walking"
        case .transit: return "transit"
        case .bicycle: return "bicycle"
        }
    }
    
    private static func formatTime(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            }
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

