//
//  FavoriteLocation.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/17/25.
//

import Foundation

enum TransportMode: String, Codable, CaseIterable {
    case automobile
    case walking
    case transit
    case bicycle
    
    var displayName: String {
        switch self {
        case .automobile:
            return "Driving"
        case .walking:
            return "Walking"
        case .transit:
            return "Transit"
        case .bicycle:
            return "Cycling"
        }
    }
}

struct FavoriteLocation: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var transportModes: [TransportMode]
    var icon: String
    var sortOrder: Int
    
    init(id: UUID = UUID(), name: String, address: String, latitude: Double, longitude: Double, 
    transportModes: [TransportMode], icon: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.transportModes = transportModes
        self.icon = icon
        self.sortOrder = sortOrder
    }
}

extension FavoriteLocation {
    // MARK: - California Test Locations (from Apple HQ, Cupertino)
    // Simulator default location: Apple HQ (37.3349, -122.0090)
    // These locations test all transit modes at various distances
    static let mockData: [FavoriteLocation] = [
        FavoriteLocation(
            name: "Santana Row",
            address: "377 Santana Row, San Jose, CA 95128",
            latitude: 37.3725,
            longitude: -121.9476,
            transportModes: [.automobile, .walking, .bicycle, .transit],  // ~4 mi - all modes viable
            icon: "bag.fill",
            sortOrder: 0
        ),
        FavoriteLocation(
            name: "Stanford",
            address: "450 Serra Mall, Stanford, CA 94305",
            latitude: 37.4275,
            longitude: -122.1697,
            transportModes: [.automobile, .bicycle, .transit],  // ~8 mi - driving, biking, transit
            icon: "building.columns.fill",
            sortOrder: 1
        ),
        FavoriteLocation(
            name: "SF Downtown",
            address: "1 Ferry Building, San Francisco, CA 94111",
            latitude: 37.7956,
            longitude: -122.3933,
            transportModes: [.automobile, .transit],  // ~45 mi - driving + Caltrain/BART
            icon: "building.2.fill",
            sortOrder: 2
        ),
        FavoriteLocation(
            name: "Google HQ",
            address: "1600 Amphitheatre Pkwy, Mountain View, CA 94043",
            latitude: 37.4220,
            longitude: -122.0841,
            transportModes: [.automobile, .bicycle, .walking, .transit],  // ~6 mi - all modes
            icon: "laptopcomputer",
            sortOrder: 3
        ),
        FavoriteLocation(
            name: "Palo Alto",
            address: "University Ave, Palo Alto, CA 94301",
            latitude: 37.4419,
            longitude: -122.1430,
            transportModes: [.automobile, .bicycle, .transit],  // ~10 mi - driving, biking, transit
            icon: "storefront.fill",
            sortOrder: 4
        )
    ]
}


