//
//  FavoritesStore.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/20/25.
//

import Foundation
import Combine

// MARK: - Errors

enum FavoritesStoreError: LocalizedError {
    case duplicateLocation
    
    var errorDescription: String? {
        switch self {
        case .duplicateLocation:
            return "A location with the same name or address already exists"
        }
    }
}

// MARK: - FavoritesStore

class FavoritesStore: ObservableObject {
    @Published var favorites: [FavoriteLocation] = []
    
    private let saveKey = "SavedFavorites"
    private let documentsDirectory: URL
    private let favoritesFileURL: URL
    
    init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        favoritesFileURL = documentsDirectory.appendingPathComponent("favorites.json")
        
        // Load saved favorites
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    /// Check if a duplicate exists (same name or same address)
    func isDuplicate(_ location: FavoriteLocation) -> Bool {
        return favorites.contains { existing in
            // Check if name matches (case insensitive)
            let nameMatch = existing.name.lowercased() == location.name.lowercased()
            // Check if address matches (case insensitive)
            let addressMatch = existing.address.lowercased() == location.address.lowercased()
            // Check if coordinates are very close (within ~10 meters)
            let latDiff = abs(existing.latitude - location.latitude)
            let lonDiff = abs(existing.longitude - location.longitude)
            let coordinateMatch = latDiff < 0.0001 && lonDiff < 0.0001
            
            return nameMatch || addressMatch || coordinateMatch
        }
    }
    
    /// Add a new favorite location
    func addFavorite(_ location: FavoriteLocation) throws {
        // Check for duplicates
        if isDuplicate(location) {
            throw FavoritesStoreError.duplicateLocation
        }
        favorites.append(location)
        saveFavorites()
    }
    
    /// Delete a favorite at specific index
    func deleteFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        saveFavorites()
    }
    
    /// Delete a specific favorite by ID
    func deleteFavorite(_ location: FavoriteLocation) {
        favorites.removeAll { $0.id == location.id }
        saveFavorites()
    }
    
    /// Update an existing favorite
    func updateFavorite(_ location: FavoriteLocation) throws {
        // Check for duplicates with other locations (not including itself)
        let duplicateExists = favorites.contains { existing in
            guard existing.id != location.id else { return false } // Skip checking against itself
            
            let nameMatch = existing.name.lowercased() == location.name.lowercased()
            let addressMatch = existing.address.lowercased() == location.address.lowercased()
            
            return nameMatch || addressMatch
        }
        
        if duplicateExists {
            throw FavoritesStoreError.duplicateLocation
        }
        
        if let index = favorites.firstIndex(where: { $0.id == location.id }) {
            favorites[index] = location
            saveFavorites()
        }
    }
    
    /// Reset to mock data (useful for testing)
    func resetToMockData() {
        favorites = FavoriteLocation.mockData
        saveFavorites()
    }
    
    // MARK: - Persistence
    /// Save favorites to JSON file
    private func saveFavorites() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(favorites)
            try data.write(to: favoritesFileURL, options: .atomic)
            print("✅ Favorites saved to: \(favoritesFileURL.path)")
        } catch {
            print("❌ Error saving favorites: \(error.localizedDescription)")
        }
    }
    
    /// Load favorites from JSON file
    private func loadFavorites() {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: favoritesFileURL.path) else {
            print("ℹ️ No saved favorites found. Loading mock data.")
            favorites = FavoriteLocation.mockData
            saveFavorites() // Create initial file with mock data
            return
        }
        
        do {
            let data = try Data(contentsOf: favoritesFileURL)
            let decoder = JSONDecoder()
            favorites = try decoder.decode([FavoriteLocation].self, from: data)
            print("✅ Loaded \(favorites.count) favorites from disk")
        } catch {
            print("❌ Error loading favorites: \(error.localizedDescription)")
            print("ℹ️ Falling back to mock data")
            favorites = FavoriteLocation.mockData
        }
    }
    
    /// Clear all favorites
    func clearAllFavorites() {
        favorites.removeAll()
        saveFavorites()
    }
    
    /// Get file path for debugging
    func getFilePath() -> String {
        return favoritesFileURL.path
    }
}

