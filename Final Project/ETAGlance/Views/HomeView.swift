//
//  ContentView.swift
//  ETAGlance
//
//  Created by Rahul Chamarthi on 11/17/25.
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    @StateObject private var store = FavoritesStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var routingService = RoutingService()
    @State private var showingAddSheet = false
    @State private var etaResults: [UUID: [TransportMode: ETAResult]] = [:]
    @State private var isLoadingETAs = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("My Locations")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAddSheet) {
                    addFavoriteSheet
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage ?? "An unknown error occurred")
                }
                .onAppear { handleOnAppear() }
                .onChange(of: locationService.currentLocation) { _, newLocation in
                    handleLocationChange(newLocation)
                }
                .onChange(of: store.favorites) { _, _ in
                    handleFavoritesChange()
                }
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showingAddSheet = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    // MARK: - Sheets
    
    private var addFavoriteSheet: some View {
        AddFavoriteView { newLocation in
            do {
                try store.addFavorite(newLocation)
                showingAddSheet = false
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ZStack {
            if store.favorites.isEmpty {
                EmptyFavoritesView()
            } else {
                favoritesList
            }
            
            if locationService.authorizationStatus == .denied {
                LocationDeniedView()
            }
        }
    }
    
    private var favoritesList: some View {
        List {
            ForEach(store.favorites) { location in
                NavigationLink {
                    EditFavoriteView(
                        location: location,
                        etaResults: etaResults[location.id] ?? [:],
                        onDelete: {
                            if let index = store.favorites.firstIndex(where: { $0.id == location.id }) {
                                store.deleteFavorite(at: IndexSet(integer: index))
                            }
                        },
                        onUpdate: { updatedLocation in
                            do {
                                try store.updateFavorite(updatedLocation)
                            } catch {
                                errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    )
                } label: {
                    LocationCard(
                        location: location,
                        etaResults: etaResults[location.id] ?? [:],
                        isLoadingETAs: isLoadingETAs
                    )
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { indexSet in
                withAnimation { store.deleteFavorite(at: indexSet) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .refreshable {
            // Haptic feedback for that premium feel
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            await fetchAllETAs()
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleOnAppear() {
        locationService.requestPermission()
    }
    
    private func handleLocationChange(_ newLocation: CLLocation?) {
        guard newLocation != nil else { return }
        Task {
            await fetchAllETAs()
        }
    }
    
    private func handleFavoritesChange() {
        // Always save favorites to widget (even without ETAs for now)
        WidgetDataService.saveWidgetData(favorites: store.favorites, etaResults: etaResults)
        
        guard locationService.currentLocation != nil else { return }
        Task {
            await fetchAllETAs()
        }
    }
    
    // MARK: - ETA Fetching
    private func fetchAllETAs() async {
        guard let userLocation = locationService.currentLocation?.coordinate else {
            print("⚠️ User location not available")
            return
        }
        
        isLoadingETAs = true
        var newResults: [UUID: [TransportMode: ETAResult]] = [:]
        
        // Fetch ETAs for each favorite location
        for favorite in store.favorites {
            let destination = CLLocationCoordinate2D(
                latitude: favorite.latitude,
                longitude: favorite.longitude
            )
            
            let results = await routingService.calculateAllETAs(
                from: userLocation,
                to: destination,
                transportModes: favorite.transportModes
            )
            
            newResults[favorite.id] = results
        }
        
        // Update on main thread
        await MainActor.run {
            etaResults = newResults
            isLoadingETAs = false
            
            // Save data for widget
            WidgetDataService.saveWidgetData(favorites: store.favorites, etaResults: newResults)
        }
        
        print("✅ Fetched ETAs for \(store.favorites.count) locations")
    }
}

struct LocationCard: View {
    let location: FavoriteLocation
    let etaResults: [TransportMode: ETAResult]
    let isLoadingETAs: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 56, height: 56)
                
                Image(systemName: location.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            
            // Name, Address, and ETA badges
            VStack(alignment: .leading, spacing: 6) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(location.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                // ETA badges - responsive layout
                ETABadgesGrid(
                    modes: location.transportModes,
                    etaResults: etaResults,
                    isLoading: isLoadingETAs
                )
                .padding(.top, 2)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - ETA Badges Row (Inline Layout)
struct ETABadgesGrid: View {
    let modes: [TransportMode]
    let etaResults: [TransportMode: ETAResult]
    let isLoading: Bool
    
    // Use compact format when 3+ modes
    private var useCompact: Bool { modes.count >= 3 }
    
    var body: some View {
        HStack(spacing: useCompact ? 4 : 6) {
            ForEach(modes, id: \.self) { mode in
                ETABadge(
                    mode: mode,
                    etaResult: etaResults[mode],
                    isLoading: isLoading,
                    isCompact: useCompact
                )
            }
        }
    }
}

// MARK: - ETA Badge
struct ETABadge: View {
    let mode: TransportMode
    let etaResult: ETAResult?
    let isLoading: Bool
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: transportModeIcon(for: mode))
                .font(.system(size: isCompact ? 10 : 12))
            
            if isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 16)
            } else if let result = etaResult {
                if let _ = result.travelTimeMinutes {
                    Text(isCompact ? result.compactTime : result.shortFormattedTime)
                        .font(.system(size: isCompact ? 10 : 12, weight: .medium))
                        .lineLimit(1)
                } else if result.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: isCompact ? 8 : 10))
                        .foregroundStyle(.orange)
                } else {
                    Text("--")
                        .font(.system(size: isCompact ? 10 : 12, weight: .medium))
                }
            } else {
                Text("--")
                    .font(.system(size: isCompact ? 10 : 12, weight: .medium))
            }
        }
        .padding(.horizontal, isCompact ? 5 : 8)
        .padding(.vertical, isCompact ? 3 : 4)
        .background(badgeColor.opacity(0.12))
        .foregroundStyle(badgeColor)
        .cornerRadius(6)
    }
    
    private var badgeColor: Color {
        switch mode {
        case .automobile: return .blue
        case .walking: return .green
        case .transit: return .orange
        case .bicycle: return .purple
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

// MARK: - Empty Favorites View

struct EmptyFavoritesView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }
            
            VStack(spacing: 8) {
                Text("No Favorite Locations")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Tap the + button to save your favorite destinations and see travel times at a glance.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Location Denied View
struct LocationDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Location Access Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("ETAGlance needs your location to calculate travel times to your favorite destinations.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                // Open Settings
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding(32)
    }
}

#Preview {
    HomeView()
}

#Preview("Empty State") {
    EmptyFavoritesView()
}

#Preview("Location Denied") {
    LocationDeniedView()
}
