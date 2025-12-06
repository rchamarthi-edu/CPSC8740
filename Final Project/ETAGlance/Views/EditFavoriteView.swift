//
//  EditFavoriteView.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/25/25.
//

import SwiftUI
import MapKit

struct EditFavoriteView: View {
    let location: FavoriteLocation
    let etaResults: [TransportMode: ETAResult]
    let onDelete: () -> Void
    let onUpdate: (FavoriteLocation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedAddress: String
    @State private var editedIcon: String
    @State private var editedTransportModes: Set<TransportMode>
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init(location: FavoriteLocation, etaResults: [TransportMode: ETAResult], onDelete: @escaping () -> Void, onUpdate: @escaping (FavoriteLocation) -> Void) {
        self.location = location
        self.etaResults = etaResults
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        _editedName = State(initialValue: location.name)
        _editedAddress = State(initialValue: location.address)
        _editedIcon = State(initialValue: location.icon)
        _editedTransportModes = State(initialValue: Set(location.transportModes))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // MARK: - Map Section
                mapView
                    .frame(height: 220)
                
                // MARK: - Location Details Section
                VStack(spacing: 20) {
                    // Location Name and Address
                    VStack(spacing: 8) {
                        if isEditing {
                            TextField("Location Name", text: $editedName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            TextField("Address", text: $editedAddress)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                        } else {
                            Text(location.name)
                                .font(.title2)
                                .fontWeight(.bold)
                        
                            Text(location.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 20)
                    
                    // MARK: - ETA List
                    if !isEditing {
                        VStack(spacing: 12) {
                            ForEach(location.transportModes, id: \.self) { mode in
                                ETARow(
                                    mode: mode,
                                    etaResult: etaResults[mode]
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // Transport mode selector when editing
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transport Modes")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(TransportMode.allCases, id: \.self) { mode in
                                    TransportModeToggle(
                                        mode: mode,
                                        isSelected: editedTransportModes.contains(mode)
                                    ) {
                                        if editedTransportModes.contains(mode) {
                                            editedTransportModes.remove(mode)
                                        } else {
                                            editedTransportModes.insert(mode)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // MARK: - Action Buttons
                    VStack(spacing: 12) {
                        // Remove from Favorites Button
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Remove from Favorites")
                                .font(.headline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 30)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Location Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))) {
            Marker(location.name, coordinate: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ))
            .tint(.blue)
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        guard !editedTransportModes.isEmpty else {
            errorMessage = "Please select at least one transport mode"
            showingError = true
            return
        }
        
        guard !editedName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Location name cannot be empty"
            showingError = true
            return
        }
        
        guard !editedAddress.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Address cannot be empty"
            showingError = true
            return
        }
        
        let updatedLocation = FavoriteLocation(
            id: location.id,
            name: editedName.trimmingCharacters(in: .whitespaces),
            address: editedAddress.trimmingCharacters(in: .whitespaces),
            latitude: location.latitude,
            longitude: location.longitude,
            transportModes: Array(editedTransportModes),
            icon: editedIcon,
            sortOrder: location.sortOrder
        )
        
        onUpdate(updatedLocation)
    }
}

// MARK: - ETA Row Component

struct ETARow: View {
    let mode: TransportMode
    let etaResult: ETAResult?
    
    var body: some View {
        HStack(spacing: 16) {
            // Transport mode icon
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: transportModeIcon(for: mode))
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
            
            // Mode name
            Text(mode.displayName)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            // ETA time
            if let result = etaResult, let _ = result.travelTimeMinutes {
                Text(result.formattedTime)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            } else {
                Text("--")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func transportModeIcon(for mode: TransportMode) -> String {
        switch mode {
        case .automobile:
            return "car.fill"
        case .walking:
            return "figure.walk"
        case .transit:
            return "bus.fill"
        case .bicycle:
            return "bicycle"
        }
    }
}

// MARK: - Transport Mode Toggle

struct TransportModeToggle: View {
    let mode: TransportMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: transportModeIcon(for: mode))
                    .font(.system(size: 18))
                Text(mode.displayName)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .foregroundStyle(isSelected ? .blue : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func transportModeIcon(for mode: TransportMode) -> String {
        switch mode {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "bus.fill"
        case .bicycle: return "bicycle"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EditFavoriteView(
            location: FavoriteLocation.mockData[0],
            etaResults: [
                .automobile: ETAResult(transportMode: .automobile, travelTimeMinutes: 25),
                .walking: ETAResult(transportMode: .walking, travelTimeMinutes: 75)
            ],
            onDelete: { print("Delete") },
            onUpdate: { _ in print("Update") }
        )
    }
}

