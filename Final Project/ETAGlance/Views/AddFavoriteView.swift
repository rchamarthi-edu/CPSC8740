//
//  AddFavoriteView.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/18/25.
//

import SwiftUI
import MapKit
import CoreLocation

struct AddFavoriteView: View {
    let onSave: (FavoriteLocation) -> Void
    
    @State private var name = ""
    @State private var address = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var selectedTransportModes: Set<TransportMode> = []
    @State private var selectedIcon = "house.fill"
    @State private var isGeocodingAddress = false
    @State private var geocodingError: String?
    @State private var addressSuggestions: [MKLocalSearchCompletion] = []
    @State private var showingSuggestions = false
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchCompleter = AddressSearchCompleter()
    
    let iconOptions = [
        "house.fill", "briefcase.fill", "star.fill", "graduationcap.fill", "bag.fill",
        "fork.knife", "wrench.fill", "cross.case.fill", "airplane", "figure.walk",
        "cart.fill", "heart.fill", "book.fill", "cup.and.saucer.fill", "building.2.fill"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Location Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("LOCATION DETAILS")
                        
                        VStack(spacing: 12) {
                            customTextField(placeholder: "Name", text: $name)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    customTextField(placeholder: "Address", text: $address)
                                    
                                    if isGeocodingAddress {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                    }
                                }
                                .onChange(of: address) { _, newValue in
                                    handleAddressChange(newValue)
                                    searchCompleter.update(queryFragment: newValue)
                                }
                                
                                // Show address suggestions
                                if showingSuggestions && !searchCompleter.suggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(searchCompleter.suggestions.prefix(5), id: \.self) { suggestion in
                                            Button {
                                                selectSuggestion(suggestion)
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(suggestion.title)
                                                        .font(.body)
                                                        .foregroundStyle(.primary)
                                                    if !suggestion.subtitle.isEmpty {
                                                        Text(suggestion.subtitle)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            if suggestion != searchCompleter.suggestions.prefix(5).last {
                                                Divider()
                                            }
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                
                                // Show geocoding status
                                if let error = geocodingError {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.red)
                                        Text(error)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 4)
                                } else if let lat = latitude, let lon = longitude {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                        Text("Location found")
                                        Spacer()
                                        Text("\(lat, specifier: "%.4f"), \(lon, specifier: "%.4f")")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Transport Modes Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("TRANSPORT MODES")
                        
                        HStack(spacing: 12) {
                            ForEach(TransportMode.allCases, id: \.self) { mode in
                                transportModeButton(mode)
                            }
                        }
                    }
                    
                    // MARK: - Icon Section
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("ICON")
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                iconButton(icon)
                            }
                        }
                    }
                    
                    // MARK: - Map Preview
                    mapPreview
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFavorite()
                    }
                    .disabled(!isValid)
                    .foregroundStyle(isValid ? .blue : .gray)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
    
    // MARK: - Custom Text Field
    
    private func customTextField(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
    }
    
    // MARK: - Transport Mode Button
    
    private func transportModeButton(_ mode: TransportMode) -> some View {
        let isSelected = selectedTransportModes.contains(mode)
        
        return Button {
            if isSelected {
                selectedTransportModes.remove(mode)
            } else {
                selectedTransportModes.insert(mode)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: transportModeIcon(for: mode))
                    .font(.system(size: 24))
                Text(transportModeShortName(for: mode))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .foregroundStyle(isSelected ? .blue : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    // MARK: - Icon Button
    
    private func iconButton(_ icon: String) -> some View {
        let isSelected = selectedIcon == icon
        
        return Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? .blue : .primary)
                .frame(width: 50, height: 50)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
    }
    
    // MARK: - Map Preview
    
    private var mapPreview: some View {
        ZStack {
            // Placeholder map background
            Color(.systemGray5)
            
            // If we have coordinates, show them on map
            if let lat = latitude, let lon = longitude {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
            } else {
                // Placeholder content
                VStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Location Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Geocoding & Suggestions
    
    private func handleAddressChange(_ newAddress: String) {
        // Clear previous results
        geocodingError = nil
        latitude = nil
        longitude = nil
        
        // Show suggestions when typing
        showingSuggestions = newAddress.count > 2
        
        // Hide suggestions if address is empty
        if newAddress.isEmpty {
            showingSuggestions = false
        }
    }
    
    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        // Build full address from suggestion
        let fullAddress = suggestion.title + ", " + suggestion.subtitle
        address = fullAddress
        showingSuggestions = false
        
        // Geocode the selected suggestion
        Task {
            await geocodeFromCompletion(suggestion)
        }
    }
    
    private func geocodeFromCompletion(_ completion: MKLocalSearchCompletion) async {
        await MainActor.run {
            isGeocodingAddress = true
            geocodingError = nil
        }
        
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        do {
            let response = try await search.start()
            
            if let mapItem = response.mapItems.first {
                await MainActor.run {
                    latitude = mapItem.placemark.coordinate.latitude
                    longitude = mapItem.placemark.coordinate.longitude
                    isGeocodingAddress = false
                    
                    // Auto-fill name if empty
                    if name.isEmpty {
                        name = mapItem.name ?? completion.title
                    }
                }
            }
        } catch {
            await MainActor.run {
                geocodingError = "Failed to find location"
                latitude = nil
                longitude = nil
                isGeocodingAddress = false
            }
        }
    }
    
    // MARK: - Validation & Save
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !address.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedTransportModes.isEmpty &&
        latitude != nil &&
        longitude != nil
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
    
    private func transportModeShortName(for mode: TransportMode) -> String {
        switch mode {
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
    
    private func saveFavorite() {
        guard let lat = latitude, let lon = longitude else {
            geocodingError = "Please enter a valid address"
            return
        }
        
        print("✅ Save tapped - Coordinates: \(lat), \(lon)")
        
        let newLocation = FavoriteLocation(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            address: address.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            transportModes: Array(selectedTransportModes),
            icon: selectedIcon,
            sortOrder: 0
        )
        
        onSave(newLocation)
        dismiss()
    }
}

// MARK: - Address Search Completer

class AddressSearchCompleter: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func update(queryFragment: String) {
        completer.queryFragment = queryFragment
    }
}

extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("❌ Address search error: \(error.localizedDescription)")
        suggestions = []
    }
}

// MARK: - Preview

#Preview {
    AddFavoriteView { location in
        print("Saved: \(location.name)")
    }
}
