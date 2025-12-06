//
//  LocationService.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/20/25.
//

import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationAvailable: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private var hasRequestedPermission = false
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        checkAuthorizationStatus()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
    }
    
    // MARK: - Public Methods
    
    /// Request location permission if not already determined
    func requestPermission() {
        guard !hasRequestedPermission else { return }
        
        switch authorizationStatus {
        case .notDetermined:
            hasRequestedPermission = true
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            break
        }
    }
    
    /// Start monitoring location updates
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            errorMessage = "Location access not authorized"
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    /// Stop monitoring location updates
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// Check current authorization status
    private func checkAuthorizationStatus() {
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        updateLocationAvailability()
    }
    
    /// Update availability flag based on status
    private func updateLocationAvailability() {
        isLocationAvailable = (authorizationStatus == .authorizedWhenInUse || 
                               authorizationStatus == .authorizedAlways) &&
                               currentLocation != nil
    }
    
    /// Get user-friendly status message
    var statusMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location permission not requested"
        case .restricted:
            return "Location access is restricted"
        case .denied:
            return "Location access denied. Enable in Settings."
        case .authorizedAlways, .authorizedWhenInUse:
            return currentLocation != nil ? "Location available" : "Waiting for location..."
        @unknown default:
            return "Unknown location status"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            authorizationStatus = manager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        updateLocationAvailability()
        
        // Auto-start if authorized
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        updateLocationAvailability()
        errorMessage = nil
        
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Failed to get location: \(error.localizedDescription)"
        print("❌ Location error: \(error.localizedDescription)")
    }
}

