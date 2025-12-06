//
//  ETAWidget.swift
//  ETAWidgetExtension
//
//  Created by Rahul Chamarthi on 11/25/25.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct ETAWidgetEntry: TimelineEntry {
    let date: Date
    let favorites: [WidgetFavorite]
    let isEmpty: Bool
    let hasError: Bool
    
    init(date: Date, favorites: [WidgetFavorite], isEmpty: Bool = false, hasError: Bool = false) {
        self.date = date
        self.favorites = favorites
        self.isEmpty = isEmpty
        self.hasError = hasError
    }
}

// MARK: - Widget Favorite Model

struct WidgetFavorite: Codable {
    let name: String
    let icon: String
    let fastestMode: String  // e.g. "automobile", "walking", "transit", "bicycle"
    let fastestTime: String
}

// MARK: - Widget Data Container (for decoding from main app)
// Must match WidgetData struct in WidgetDataService.swift

struct WidgetDataContainer: Codable {
    let favorites: [WidgetFavoriteData]
    let lastUpdated: Date
}

struct WidgetFavoriteData: Codable {
    let name: String
    let icon: String
    let fastestMode: String  // "automobile", "walking", "transit", "bicycle"
    let fastestTime: String
    let fastestTimeMinutes: Int
}

// MARK: - Timeline Provider

struct ETAWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ETAWidgetEntry {
        ETAWidgetEntry(date: Date(), favorites: placeholderFavorites())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ETAWidgetEntry) -> Void) {
        let entry = ETAWidgetEntry(date: Date(), favorites: placeholderFavorites())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ETAWidgetEntry>) -> Void) {
        let (favorites, isEmpty, hasError) = loadFavorites()
        let entry = ETAWidgetEntry(date: Date(), favorites: favorites, isEmpty: isEmpty, hasError: hasError)
        
        // Refresh every 10 minutes for faster updates
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadFavorites() -> (favorites: [WidgetFavorite], isEmpty: Bool, hasError: Bool) {
        let appGroupIdentifier = "group.com.ethaglance.shared"
        let widgetDataKey = "widget_eta_data"
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ [Widget] Failed to access App Group")
            return (placeholderFavorites(), false, true)
        }
        
        guard let data = sharedDefaults.data(forKey: widgetDataKey) else {
            print("⚠️ [Widget] No shared data found")
            return ([], true, false)
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let widgetData = try decoder.decode(WidgetDataContainer.self, from: data)
            
            if widgetData.favorites.isEmpty {
                return ([], true, false)
            }
            
            let favorites = widgetData.favorites.map { favorite in
                WidgetFavorite(
                    name: favorite.name,
                    icon: favorite.icon,
                    fastestMode: favorite.fastestMode,
                    fastestTime: favorite.fastestTime
                )
            }
            
            print("✅ [Widget] Loaded \(favorites.count) favorites")
            return (favorites, false, false)
        } catch {
            print("❌ [Widget] Decode error: \(error)")
            return ([], false, true)
        }
    }
    
    private func placeholderFavorites() -> [WidgetFavorite] {
        return [
            WidgetFavorite(name: "Work", icon: "briefcase.fill", fastestMode: "automobile", fastestTime: "18 min"),
            WidgetFavorite(name: "Home", icon: "house.fill", fastestMode: "walking", fastestTime: "25 min"),
            WidgetFavorite(name: "Gym", icon: "figure.run", fastestMode: "automobile", fastestTime: "12 min"),
            WidgetFavorite(name: "Coffee", icon: "cup.and.saucer.fill", fastestMode: "walking", fastestTime: "8 min")
        ]
    }
}

// MARK: - Widget View

struct ETAWidgetView: View {
    let entry: ETAWidgetEntry
    
    var body: some View {
        Group {
            if entry.hasError {
                ErrorStateView()
            } else if entry.isEmpty {
                EmptyStateView()
            } else {
                FavoritesGridView(favorites: entry.favorites)
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

// MARK: - Favorites Grid View

struct FavoritesGridView: View {
    let favorites: [WidgetFavorite]
    
    private var displayedFavorites: [WidgetFavorite] {
        Array(favorites.prefix(4))
    }
    
    private var hasMore: Bool {
        favorites.count > 4
    }
    
    private var moreCount: Int {
        favorites.count - 4
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Main content with even spacing
            HStack(spacing: 0) {
                ForEach(displayedFavorites.indices, id: \.self) { index in
                    FavoriteColumn(favorite: displayedFavorites[index], isCompact: hasMore)
                        .padding(.horizontal, 4)
                    
                    // Subtle divider between columns
                    if index < displayedFavorites.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .frame(width: 1)
                            .padding(.vertical, hasMore ? 20 : 16)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            
            // "More" pill indicator
            if hasMore {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("+\(moreCount) more")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.05)))
                .padding(.bottom, 4)
            }
        }
        .padding(.top, hasMore ? 6 : 10)
        .padding(.bottom, hasMore ? 0 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "mappin.slash")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 2) {
                Text("No Favorites")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Add locations in the app")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 2) {
                Text("Unable to Load")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text("Open app to refresh")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Favorite Column (polished design)

struct FavoriteColumn: View {
    let favorite: WidgetFavorite
    var isCompact: Bool = false  // true when "+more" is shown
    
    private var accentColor: Color {
        transportModeColor(for: favorite.fastestMode)
    }
    
    // Adaptive sizing
    private var nameSize: CGFloat { isCompact ? 11 : 12 }
    private var iconCircleSize: CGFloat { isCompact ? 34 : 40 }
    private var iconSize: CGFloat { isCompact ? 15 : 18 }
    private var etaIconSize: CGFloat { isCompact ? 9 : 10 }
    private var etaFontSize: CGFloat { isCompact ? 10 : 11 }
    private var pillPadH: CGFloat { isCompact ? 7 : 9 }
    private var pillPadV: CGFloat { isCompact ? 4 : 5 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Location name - fixed size, truncated with ellipsis
            Text(abbreviateName(favorite.name))
                .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: 18)
            
            Spacer(minLength: isCompact ? 4 : 6)
            
            // Icon with subtle background
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: iconCircleSize, height: iconCircleSize)
                
                Image(systemName: favorite.icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(accentColor)
            }
            
            Spacer(minLength: isCompact ? 4 : 6)
            
            // ETA pill - fixed at bottom
            HStack(spacing: 3) {
                Image(systemName: transportModeIcon(for: favorite.fastestMode))
                    .font(.system(size: etaIconSize, weight: .bold))
                
                Text(formatCompactTime(favorite.fastestTime))
                    .font(.system(size: etaFontSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, pillPadH)
            .padding(.vertical, pillPadV)
            .background(
                Capsule()
                    .fill(accentColor.opacity(0.12))
            )
            .foregroundStyle(accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Abbreviate long names to keep consistent sizing
    private func abbreviateName(_ name: String) -> String {
        // Common abbreviations for cleaner display
        var shortened = name
            .replacingOccurrences(of: "Downtown", with: "Dwntn")
            .replacingOccurrences(of: "University", with: "Univ")
            .replacingOccurrences(of: "Station", with: "Stn")
            .replacingOccurrences(of: "Center", with: "Ctr")
            .replacingOccurrences(of: "Street", with: "St")
            .replacingOccurrences(of: "Avenue", with: "Ave")
        
        // If still too long (>10 chars), truncate
        if shortened.count > 10 {
            shortened = String(shortened.prefix(9)) + "…"
        }
        
        return shortened
    }
    
    // Format time cleanly: "1h 27m" -> "1h 27", "18 min" -> "18m", "12h 30m" -> "12h+"
    private func formatCompactTime(_ time: String) -> String {
        let t = time.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle "X min" format -> "Xm"
        if t.contains("min") && !t.contains("h") {
            let num = t.replacingOccurrences(of: " ", with: "")
                       .replacingOccurrences(of: "min", with: "m")
            return num
        }
        
        // Handle hour formats
        if t.contains("h") {
            let parts = t.components(separatedBy: "h")
            if parts.count >= 2 {
                let hoursStr = parts[0].trimmingCharacters(in: .whitespaces)
                let hours = Int(hoursStr) ?? 0
                
                // 10+ hours: abbreviate to "Xh+"
                if hours >= 10 {
                    return "\(hours)h+"
                }
                
                // Extract minutes
                let minPart = parts[1]
                    .replacingOccurrences(of: "r", with: "")
                    .replacingOccurrences(of: "min", with: "")
                    .replacingOccurrences(of: "m", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if let mins = Int(minPart), mins > 0 {
                    // Clean format: "1h 27"
                    return "\(hours)h \(mins)"
                }
                return "\(hours)h"
            }
        }
        
        // Already compact or unknown format
        return time
    }
    
    private func transportModeIcon(for mode: String) -> String {
        switch mode.lowercased() {
        case "automobile": return "car.fill"
        case "walking": return "figure.walk"
        case "transit": return "bus.fill"
        case "bicycle": return "bicycle"
        default: return "car.fill"
        }
    }
    
    private func transportModeColor(for mode: String) -> Color {
        switch mode.lowercased() {
        case "automobile": return .blue
        case "walking": return .green
        case "transit": return .orange
        case "bicycle": return .purple
        default: return .blue
        }
    }
}

// MARK: - Widget Configuration

struct ETAWidget: Widget {
    let kind: String = "ETAWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ETAWidgetProvider()) { entry in
            ETAWidgetView(entry: entry)
        }
        .configurationDisplayName("ETA Glance")
        .description("See travel times to your favorite destinations at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct ETAWidgetBundle: WidgetBundle {
    var body: some Widget {
        ETAWidget()
    }
}

// MARK: - Preview

#Preview("Normal", as: .systemMedium) {
    ETAWidget()
} timeline: {
    ETAWidgetEntry(date: Date(), favorites: [
        WidgetFavorite(name: "Work", icon: "briefcase.fill", fastestMode: "automobile", fastestTime: "18 min"),
        WidgetFavorite(name: "Home", icon: "house.fill", fastestMode: "walking", fastestTime: "25 min"),
        WidgetFavorite(name: "Gym", icon: "figure.run", fastestMode: "transit", fastestTime: "12 min"),
        WidgetFavorite(name: "Coffee", icon: "cup.and.saucer.fill", fastestMode: "bicycle", fastestTime: "8 min")
    ])
}

#Preview("With More", as: .systemMedium) {
    ETAWidget()
} timeline: {
    ETAWidgetEntry(date: Date(), favorites: [
        WidgetFavorite(name: "Work", icon: "briefcase.fill", fastestMode: "automobile", fastestTime: "18 min"),
        WidgetFavorite(name: "Home", icon: "house.fill", fastestMode: "walking", fastestTime: "25 min"),
        WidgetFavorite(name: "Gym", icon: "figure.run", fastestMode: "transit", fastestTime: "12 min"),
        WidgetFavorite(name: "Coffee", icon: "cup.and.saucer.fill", fastestMode: "bicycle", fastestTime: "8 min"),
        WidgetFavorite(name: "Store", icon: "cart.fill", fastestMode: "automobile", fastestTime: "15 min"),
        WidgetFavorite(name: "Park", icon: "leaf.fill", fastestMode: "walking", fastestTime: "10 min")
    ])
}

#Preview("Empty", as: .systemMedium) {
    ETAWidget()
} timeline: {
    ETAWidgetEntry(date: Date(), favorites: [], isEmpty: true)
}

#Preview("Error", as: .systemMedium) {
    ETAWidget()
} timeline: {
    ETAWidgetEntry(date: Date(), favorites: [], hasError: true)
}

