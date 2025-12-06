//
//  ETAStressTestView.swift
//  ETAGlance
//
//  Created for stress testing ETA functionality
//

import SwiftUI
import CoreLocation

struct ETAStressTestView: View {
    @StateObject private var routingService = RoutingService()
    @StateObject private var locationService = LocationService()
    
    @State private var isRunningTest = false
    @State private var testResults: [String: (success: Bool, duration: TimeInterval, eta: ETAResult?)] = [:]
    @State private var selectedMode: TransportMode = .automobile
    @State private var testLog: [String] = []
    
    // Test destinations (Atlanta area)
    private let testDestinations: [(name: String, coordinate: CLLocationCoordinate2D)] = [
        ("Downtown Atlanta", CLLocationCoordinate2D(latitude: 33.7490, longitude: -84.3880)),
        ("Midtown", CLLocationCoordinate2D(latitude: 33.7701, longitude: -84.3860)),
        ("Buckhead", CLLocationCoordinate2D(latitude: 33.8490, longitude: -84.3671)),
        ("Piedmont Park", CLLocationCoordinate2D(latitude: 33.7890, longitude: -84.3850)),
        ("Georgia Tech", CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)),
        ("Emory University", CLLocationCoordinate2D(latitude: 33.7920, longitude: -84.3242)),
        ("Hartsfield Airport", CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277)),
        ("Lenox Square", CLLocationCoordinate2D(latitude: 33.8469, longitude: -84.3617)),
        ("Ponce City Market", CLLocationCoordinate2D(latitude: 33.7726, longitude: -84.3652)),
        ("Atlantic Station", CLLocationCoordinate2D(latitude: 33.7914, longitude: -84.3982))
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stress Test Settings")
                        .font(.headline)
                    
                    // Transport mode picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transport Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Picker("Transport Mode", selection: $selectedMode) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Test button
                    Button(action: runStressTest) {
                        HStack {
                            if isRunningTest {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "flame.fill")
                            }
                            Text(isRunningTest ? "Running Test..." : "Run Stress Test")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isRunningTest ? Color.gray : Color.orange)
                        .cornerRadius(12)
                    }
                    .disabled(isRunningTest || locationService.currentLocation == nil)
                    
                    if locationService.currentLocation == nil {
                        Text("⚠️ Waiting for location...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !testResults.isEmpty {
                            // Summary
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Results")
                                    .font(.headline)
                                
                                let successCount = testResults.values.filter { $0.success }.count
                                let avgDuration = testResults.values.map { $0.duration }.reduce(0, +) / Double(testResults.count)
                                
                                HStack {
                                    Label("\(successCount)/\(testResults.count) successful", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(successCount == testResults.count ? .green : .orange)
                                    Spacer()
                                    Text("Avg: \(String(format: "%.2f", avgDuration))s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            
                            // Individual results
                            ForEach(Array(testResults.keys.sorted()), id: \.self) { key in
                                if let result = testResults[key] {
                                    StressTestResultRow(
                                        destination: key,
                                        success: result.success,
                                        duration: result.duration,
                                        eta: result.eta
                                    )
                                }
                            }
                        }
                        
                        // Log
                        if !testLog.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test Log")
                                    .font(.headline)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(testLog, id: \.self) { log in
                                        Text(log)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("ETA Stress Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationService.requestPermission()
            }
        }
    }
    
    private func runStressTest() {
        guard let userLocation = locationService.currentLocation?.coordinate else {
            addLog("❌ User location not available")
            return
        }
        
        isRunningTest = true
        testResults.removeAll()
        testLog.removeAll()
        addLog("🔥 Starting stress test with \(selectedMode.displayName)")
        addLog("📍 Testing \(testDestinations.count) destinations")
        
        Task {
            let results = await routingService.stressTestETAs(
                from: userLocation,
                destinations: testDestinations,
                transportMode: selectedMode
            )
            
            await MainActor.run {
                testResults = results
                isRunningTest = false
                
                let successCount = results.values.filter { $0.success }.count
                addLog("✅ Test complete: \(successCount)/\(results.count) successful")
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        testLog.append("[\(timestamp)] \(message)")
    }
}

struct StressTestResultRow: View {
    let destination: String
    let success: Bool
    let duration: TimeInterval
    let eta: ETAResult?
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(success ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(destination)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let eta = eta, let travelTime = eta.travelTimeMinutes {
                    Text("ETA: \(eta.formattedTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let eta = eta, let error = eta.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("No result")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(String(format: "%.2f", duration))s")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    ETAStressTestView()
}

