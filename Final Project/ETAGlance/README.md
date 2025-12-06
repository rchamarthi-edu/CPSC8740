# Project Context: ETA Glance (iOS)

This is an iOS 17+ SwiftUI app called ETAGlance. The app shows the user estimated travel times (ETAs) to their favorite locations.

Key features:
- User can add/edit/delete favorite locations
- FavoriteLocation model includes name, icon, address, coordinates, transport mode
- ETAs computed using MapKit (MKDirections)
- Current location via CoreLocation
- Data persisted locally (JSON or UserDefaults, not SwiftData)

Future feature (important to plan for):
- A beautiful WidgetKit widget (home screen + lock screen) that displays:
    - Next event ETA (calendar integration)
    - Top 2–3 favorite locations with ETAs
    - Clean design, minimal layout, fast load times
    - Uses shared storage via App Groups

What I'm working on right now:
- Basic app structure
- Home screen UI (SwiftUI)
- Static FavoriteLocation list
- Add-Favorite button (non-functional for now)

Important:
- Use clean SwiftUI architecture and avoid unnecessary complexity.
- Do NOT scaffold widget code yet; just keep it in mind as a future target.