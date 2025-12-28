# Grab - Territory Running Game

A territory-based running game for iOS where users claim real-world areas by running closed loops around them.

## Core Concept

- Run in the real world to claim territory
- Complete a closed-loop run to own the area you ran around
- Territory is visible on a map using hexagonal cells
- Other runners can steal your territory by running around the same area
- Ownership is determined by the most recent valid run

## Tech Stack

- **Swift** + **SwiftUI** for UI
- **MapKit** for map display and territory overlays
- **CoreLocation** for GPS tracking
- **H3 Hex Grid** (simplified implementation) for territory representation
- **Local Storage** (UserDefaults) for MVP data persistence

## Features

### Tab 1: Home (Map)
- Full-screen map with territory hex overlays
- Color-coded territories:
  - Blue: Your territory
  - Orange: Other users' territory
- Tap on any hex to see ownership details
- Bottom sheet shows owner, claim date, run distance, and area

### Tab 2: Run
- Start/stop GPS tracking
- Live stats: elapsed time, distance, pace
- Mini map showing current path
- Loop detection and validation
- Territory claiming on valid loop completion

### Tab 3: Profile
- User stats (total runs, distance, territory owned)
- Mini map preview of owned territory
- Sign out option

## Run Validation Rules

A run is valid if:
- Distance ≥ 100 meters
- Duration ≥ 30 seconds
- At least 10 GPS points recorded
- Start and end points within 50 meters (closed loop)
- No unrealistic speed spikes (max ~43 km/h)
- GPS accuracy ≤ 50 meters

## H3 Hex Grid

The app uses a simplified H3-like hexagonal grid system:
- Resolution 9: ~0.1 km² per hex
- Territory is represented as a set of hex cell IDs
- Claiming = updating ownership of hex cells inside the run polygon
- Stealing = overwriting existing ownership with new runner

## Project Structure

```
Grab/
├── Models/
│   ├── User.swift           # User and UserStats models
│   ├── Run.swift            # Run and GPSPoint models
│   └── TerritoryHex.swift   # Territory hex model
├── Services/
│   ├── AuthService.swift       # User authentication (local)
│   ├── LocationService.swift   # GPS tracking
│   ├── LocalStorageService.swift # Data persistence
│   ├── RunTrackingService.swift  # Run tracking & validation
│   └── TerritoryService.swift    # Territory data management
├── Utilities/
│   └── H3Utils.swift         # Hex grid calculations
├── Views/
│   ├── Components/
│   │   ├── HexagonOverlay.swift      # MapKit hex overlay
│   │   └── TerritoryBottomSheet.swift # Territory details sheet
│   ├── Home/
│   │   ├── HomeView.swift    # Main map screen
│   │   └── MapView.swift     # UIKit MapView wrapper
│   ├── Run/
│   │   ├── RunView.swift     # Run tracking screen
│   │   └── RunMapView.swift  # Mini map for runs
│   ├── Profile/
│   │   └── ProfileView.swift # User profile screen
│   ├── Onboarding/
│   │   └── OnboardingView.swift # Username setup
│   ├── MainTabView.swift     # Tab bar container
│   └── RootView.swift        # Auth state handler
├── GrabApp.swift             # App entry point
└── Info.plist                # Location permissions
```

## Setup Instructions

### Requirements
- Xcode 15+
- iOS 17+
- Physical device recommended (for GPS)

### Running the App

1. Open `Grab.xcodeproj` in Xcode
2. Select your target device (physical device recommended)
3. Build and run (⌘R)
4. Allow location permissions when prompted
5. Create a username to get started

### Important Notes

- **Location Permission**: The app requires "When In Use" or "Always" location permission
- **Background Location**: Enabled for tracking runs while phone is locked
- **Simulator Limitations**: GPS simulation works but is less accurate than real device

## Future Enhancements (Backend)

When ready to add Supabase backend:

### Database Schema

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT NOT NULL UNIQUE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Runs table
CREATE TABLE runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id),
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL,
  distance_m DOUBLE PRECISION,
  duration_s DOUBLE PRECISION,
  valid_loop BOOLEAN DEFAULT FALSE,
  path GEOMETRY(LINESTRING, 4326),
  loop_polygon GEOMETRY(POLYGON, 4326),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Territory hexes table
CREATE TABLE territory_hex (
  hex_id TEXT PRIMARY KEY,
  owner_user_id UUID REFERENCES users(id),
  last_run_id UUID REFERENCES runs(id),
  claimed_at TIMESTAMPTZ
);

-- Indexes
CREATE INDEX idx_territory_owner ON territory_hex(owner_user_id);
CREATE INDEX idx_runs_user ON runs(user_id);
```

### Edge Functions

1. `POST /submitRun` - Validate and process run, claim territory
2. `GET /territoryInViewport` - Get territory hexes in map viewport

## Anti-Cheat Considerations

The app validates runs to prevent cheating:
- Speed validation (reject impossible speeds)
- Accuracy filtering (ignore poor GPS data)
- Teleport detection (reject location jumps)
- Minimum thresholds (distance, duration, points)
- Loop closure verification

## License

MIT License
