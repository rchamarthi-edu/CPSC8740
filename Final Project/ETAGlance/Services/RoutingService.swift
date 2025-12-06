//
//  RoutingService.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/21/25.
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Errors
enum ETAError: Error {
    case timeout
    case noRouteFound
}

// MARK: - ETA Data Model
struct ETAResult {
    let transportMode: TransportMode
    let travelTimeMinutes: Int?
    let distance: Double?
    let isLoading: Bool
    let error: String?
    
    init(transportMode: TransportMode, travelTimeMinutes: Int? = nil, distance: Double? = nil, isLoading: Bool = false, error: String? = nil) {
        self.transportMode = transportMode
        self.travelTimeMinutes = travelTimeMinutes
        self.distance = distance
        self.isLoading = isLoading
        self.error = error
    }
    
    var formattedTime: String {
        guard let minutes = travelTimeMinutes else {
            return "--"
        }
        
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
    
    var shortFormattedTime: String {
        guard let minutes = travelTimeMinutes else {
            return "--"
        }
        
        if minutes < 60 {
            return "\(minutes)min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)hr"
            }
            return "\(hours)hr \(remainingMinutes)min"
        }
    }
    
    /// Ultra-compact format for tight spaces (e.g., "44m", "2h", "19h")
    var compactTime: String {
        guard let minutes = travelTimeMinutes else {
            return "--"
        }
        
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            // For very long trips, just show hours
            if hours >= 10 || remainingMinutes == 0 {
                return "\(hours)h"
            }
            // For moderate trips, show hours.fraction
            let fraction = Double(remainingMinutes) / 60.0
            if fraction >= 0.5 {
                return "\(hours).5h"
            }
            return "\(hours)h"
        }
    }
}

// MARK: - Routing Service

class RoutingService: ObservableObject {
    
    // Configuration
    private let maxRetries = 2
    private let requestTimeout: TimeInterval = 15.0
    
    // MARK: - Public Methods
    
    /// Calculate ETA from origin to destination for a specific transport mode
    /// Includes retry logic and timeout handling
    func calculateETA(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportMode: TransportMode
    ) async -> ETAResult {
        
        // Try with retries
        for attempt in 0...maxRetries {
            if attempt > 0 {
                print("🔄 [ETA] Retry attempt \(attempt) for \(transportMode.displayName)")
                // Brief delay before retry
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            let result = await calculateETAWithTimeout(
                from: origin,
                to: destination,
                transportMode: transportMode,
                attempt: attempt + 1
            )
            
            // If successful, return immediately
            if result.travelTimeMinutes != nil {
                return result
            }
            
            // If it's a "no route" error (e.g., transit not available), don't retry
            if let error = result.error, error.contains("not available") || error.contains("No route") {
                return result
            }
        }
        
        // All retries failed
        print("❌ [ETA] All retry attempts failed for \(transportMode.displayName)")
        return ETAResult(
            transportMode: transportMode,
            error: "Failed after \(maxRetries + 1) attempts"
        )
    }
    
    /// Calculate ETA with timeout handling
    private func calculateETAWithTimeout(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportMode: TransportMode,
        attempt: Int
    ) async -> ETAResult {
        
        let startTime = Date()
        print("🚀 [ETA] Attempt #\(attempt) for \(transportMode.displayName)")
        print("   Origin: \(origin.latitude), \(origin.longitude)")
        print("   Destination: \(destination.latitude), \(destination.longitude)")
        
        // Create placemark items
        let originPlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        // Create map items
        let originItem = MKMapItem(placemark: originPlacemark)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        
        // Create directions request
        let request = MKDirections.Request()
        request.source = originItem
        request.destination = destinationItem
        request.transportType = mapKitTransportType(for: transportMode)
        request.requestsAlternateRoutes = true // Request multiple routes to find fastest
        
        // Create directions object
        let directions = MKDirections(request: request)
        
        do {
            // Use Task with timeout
            let response = try await withThrowingTaskGroup(of: MKDirections.Response.self) { group in
                // Add the calculation task
                group.addTask {
                    try await directions.calculate()
                }
                
                // Add timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(self.requestTimeout * 1_000_000_000))
                    throw ETAError.timeout
                }
                
                // Return first completed task
                let result = try await group.next()!
                group.cancelAll() // Cancel the other task
                return result
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            guard !response.routes.isEmpty else {
                print("⚠️ [ETA] No route found for \(transportMode.displayName) (took \(String(format: "%.2f", duration))s)")
                return ETAResult(
                    transportMode: transportMode,
                    error: "No route available for \(transportMode.displayName)"
                )
            }
            
            // Find the fastest route
            let fastestRoute = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })!
            
            let travelTimeMinutes = Int(ceil(fastestRoute.expectedTravelTime / 60.0))
            let distanceMeters = fastestRoute.distance
            
            if response.routes.count > 1 {
                print("✅ [ETA] Success for \(transportMode.displayName): \(travelTimeMinutes) min (fastest of \(response.routes.count) routes), \(String(format: "%.2f", distanceMeters/1000)) km (took \(String(format: "%.2f", duration))s)")
            } else {
                print("✅ [ETA] Success for \(transportMode.displayName): \(travelTimeMinutes) min, \(String(format: "%.2f", distanceMeters/1000)) km (took \(String(format: "%.2f", duration))s)")
            }
            
            return ETAResult(
                transportMode: transportMode,
                travelTimeMinutes: travelTimeMinutes,
                distance: distanceMeters
            )
            
        } catch ETAError.timeout {
            let duration = Date().timeIntervalSince(startTime)
            print("⏱️ [ETA] Timeout for \(transportMode.displayName) after \(String(format: "%.2f", duration))s")
            return ETAResult(
                transportMode: transportMode,
                error: "Request timed out"
            )
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [ETA] MKDirections FAILED for \(transportMode.displayName) (took \(String(format: "%.2f", duration))s)")
            print("   Error: \(error.localizedDescription)")
            print("   Error Code: \((error as NSError).code)")
            print("   Error Domain: \((error as NSError).domain)")
            
            // Check for transit not available error
            let nsError = error as NSError
            if nsError.domain == MKError.errorDomain && nsError.code == MKError.directionsNotFound.rawValue {
                return ETAResult(
                    transportMode: transportMode,
                    error: "\(transportMode.displayName) not available in this area"
                )
            }
            
            return ETAResult(
                transportMode: transportMode,
                error: error.localizedDescription
            )
        }
    }
    
    /// Calculate ETAs for all transport modes for a given destination
    func calculateAllETAs(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportModes: [TransportMode]
    ) async -> [TransportMode: ETAResult] {
        
        var results: [TransportMode: ETAResult] = [:]
        
        // Calculate ETAs for each transport mode
        await withTaskGroup(of: (TransportMode, ETAResult).self) { group in
            for mode in transportModes {
                group.addTask {
                    let result = await self.calculateETA(
                        from: origin,
                        to: destination,
                        transportMode: mode
                    )
                    return (mode, result)
                }
            }
            
            for await (mode, result) in group {
                results[mode] = result
            }
        }
        
        return results
    }
    
    /// Get the fastest ETA from a set of results
    func getFastestETA(from results: [TransportMode: ETAResult]) -> (mode: TransportMode, result: ETAResult)? {
        let validResults = results.filter { $0.value.travelTimeMinutes != nil }
        
        guard !validResults.isEmpty else {
            return nil
        }
        
        let fastest = validResults.min { (a, b) in
            guard let aTime = a.value.travelTimeMinutes,
                  let bTime = b.value.travelTimeMinutes else {
                return false
            }
            return aTime < bTime
        }
        
        if let fastest = fastest {
            return (fastest.key, fastest.value)
        }
        
        return nil
    }
    
    /// Stress test: Calculate ETAs rapidly for multiple destinations
    func stressTestETAs(
        from origin: CLLocationCoordinate2D,
        destinations: [(name: String, coordinate: CLLocationCoordinate2D)],
        transportMode: TransportMode
    ) async -> [String: (success: Bool, duration: TimeInterval, eta: ETAResult?)] {
        
        print("🔥 [STRESS TEST] Starting for \(destinations.count) destinations with \(transportMode.displayName)")
        let overallStart = Date()
        var results: [String: (success: Bool, duration: TimeInterval, eta: ETAResult?)] = [:]
        
        // Test rapid succession (serial)
        for destination in destinations {
            let start = Date()
            let eta = await calculateETA(
                from: origin,
                to: destination.coordinate,
                transportMode: transportMode
            )
            let duration = Date().timeIntervalSince(start)
            
            results[destination.name] = (
                success: eta.travelTimeMinutes != nil,
                duration: duration,
                eta: eta
            )
        }
        
        let totalDuration = Date().timeIntervalSince(overallStart)
        
        let successCount = results.values.filter { $0.success }.count
        print("🔥 [STRESS TEST] Completed: \(successCount)/\(destinations.count) successful in \(String(format: "%.2f", totalDuration))s")
        
        return results
    }
    
    // MARK: - Private Helpers
    
    private func mapKitTransportType(for mode: TransportMode) -> MKDirectionsTransportType {
        switch mode {
        case .automobile:
            return .automobile
        case .walking:
            return .walking
        case .transit:
            return .transit
        case .bicycle:
            // MapKit doesn't have bicycle, so we use walking as approximation
            // In production, you might want to use a third-party API for cycling routes
            return .walking
        }
    }
}

// MARK: - Test Coordinates

extension RoutingService {
    /// Test coordinates for development
    static let testCoordinates = TestLocations()
    
    struct TestLocations {
        // Atlanta, GA area coordinates
        let atlantaDowntown = CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)
        let atlantaMidtown = CLLocationCoordinate2D(latitude: 33.7701, longitude: -84.3860)
        let atlantaBuckhead = CLLocationCoordinate2D(latitude: 33.8490, longitude: -84.3671)
        let atlantaPiedmontPark = CLLocationCoordinate2D(latitude: 33.7890, longitude: -84.3850)
        let atlantaClemson = CLLocationCoordinate2D(latitude: 34.6834, longitude: -82.8374)
        
        // For testing purposes
        var userLocation: CLLocationCoordinate2D {
            // Default to Atlanta Downtown as test location
            return atlantaDowntown
        }
    }
}

