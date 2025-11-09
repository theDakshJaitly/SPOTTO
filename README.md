# Spotto - Predictive Parking App

A Flutter-based mobile application that helps users find available parking spots with real-time probability predictions. Spotto uses AI-powered simulations to predict parking availability and provides navigation integration with popular map apps.

## Features

### 🗺️ Interactive Map
- Real-time map view with parking zone boundaries
- GPS location tracking with user's current position indicator
- Draggable bottom sheet for zone details
- Search functionality to find parking zones by location

### 🔍 Smart Search
- Mock search suggestions with 40+ locations
- Real-time filtering as you type
- Visual indicators for locations with parking zones
- Search overlay with full-screen experience

### 📊 Parking Zone Management
- Dynamic parking zones with polygon boundaries
- Real-time availability probability (0-100%)
- Zone details with statistics:
  - Current availability percentage
  - Last updated timestamp
  - Average parking time
  - Probability history chart

### 🧭 Navigation Integration
- External app handoff to popular navigation apps:
  - Google Maps
  - Apple Maps
  - Waze
- Automatic route calculation with origin and destination
- Seamless transition between apps

### 🎯 User Features
- "I Parked Here" functionality to mark parking sessions
- Active parking timer with duration tracking
- Points and rewards system
- User profile with badges and achievements

### 📱 Live Simulation
- AI-powered probability updates every 5 seconds
- Dynamic zone availability changes
- Realistic parking behavior simulation

## Tech Stack

- **Framework**: Flutter 3.0+
- **Maps**: flutter_map with OpenStreetMap tiles
- **Location Services**: geolocator, geocoding
- **Charts**: fl_chart for probability visualization
- **Navigation**: url_launcher for external app integration
- **UI**: Material Design with Google Fonts

## Dependencies

```yaml
dependencies:
  flutter_map: ^8.2.2
  latlong2: ^0.9.0
  fl_chart: ^0.68.0
  google_fonts: ^6.3.2
  phosphor_flutter: ^2.0.1
  geolocator: ^12.0.0
  geocoding: ^3.0.0
  http: ^1.2.0
  url_launcher: ^6.2.5
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / Xcode (for mobile development)
- An Android emulator or iOS simulator, or a physical device

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd SPOTTO
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK: 21 (Android 5.0)
- Location permissions are automatically requested at runtime

#### iOS
- Minimum iOS version: 12.0
- Add location permissions to `Info.plist`:
  ```xml
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Spotto needs your location to find nearby parking zones</string>
  ```

## Project Structure

```
lib/
├── data/
│   └── mock_data.dart          # Mock parking zones and search suggestions
├── models/
│   ├── parking_zone.dart       # Parking zone data model
│   ├── zone_details.dart       # Zone details and statistics
│   ├── search_suggestion.dart  # Search suggestion model
│   └── user_profile.dart       # User profile and badges
├── screens/
│   ├── map_screen.dart         # Main map screen with zones
│   └── zone_details_screen.dart # Zone details bottom sheet
├── services/
│   └── navigation_service.dart  # External navigation app integration
└── main.dart                   # App entry point
```

## Key Features Explained

### Parking Zone Search
- Search for locations by name
- Filter suggestions in real-time
- Locations marked with "Zones" badge have parking availability
- Selecting a location moves the map and loads zones (if available)

### Zone Availability
- Zones with availability show probability percentage
- Color-coded indicators:
  - 🟢 Green: >70% availability
  - 🟠 Orange: 30-70% availability
  - 🔴 Red: <30% availability

### Navigation Handoff
1. Tap a parking zone to view details
2. Tap "Navigate" button
3. Choose your preferred navigation app
4. External app opens with route from your location to the zone
5. Return to Spotto to confirm parking

### Mock Data
The app currently uses mock data for:
- Parking zones (4 default zones)
- Search suggestions (40+ locations)
- Zone availability probabilities
- User profile and badges

## Development Notes

### Location Services
- The app requests location permissions on first launch
- GPS status is monitored in real-time
- Falls back to default location if GPS is unavailable

### Zone Generation
- Parking zones are generated relative to user's current location
- Zones are dynamically positioned based on GPS coordinates
- Mock zones are shifted to appear near the user

### Search Functionality
- Uses mock search suggestions (no API required)
- Filters suggestions based on name matching
- Shows visual indicators for zones availability

## Future Enhancements

- [ ] Real-time API integration for parking data
- [ ] User authentication and profile sync
- [ ] Parking history and favorites
- [ ] Push notifications for zone availability
- [ ] Social features (share parking spots)
- [ ] Payment integration for parking fees
- [ ] Offline map support

## Contributing

This is a prototype application. Contributions and suggestions are welcome!

## License

This project is for educational/demonstration purposes.

## Contact

For questions or feedback, please open an issue in the repository.

---

**Note**: This app uses mock data for demonstration purposes. Real parking zone data would require integration with parking management APIs or services.
