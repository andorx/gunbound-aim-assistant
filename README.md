<p align="center">
  <img src="icon.png" width="128" height="128" alt="Gunbound Aim Assistant">
</p>

<h1 align="center">Gunbound Aim Assistant</h1>

<p align="center">
  A native macOS overlay tool that calculates and visualizes projectile trajectories for <strong>Gunbound M</strong> (and Gunbound-style games), helping you line up the perfect shot every time.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="macOS 13+">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

## ✨ Features

- **Real-time trajectory overlay** — A transparent, always-on-top window draws projectile paths directly over the game
- **Wind physics simulation** — Euler-integration physics engine with configurable wind force (1–12) and direction (clock-face knob)
- **Power auto-solver** — Automatically calculates the optimal shot power to hit a target given angle and wind
- **Up to 3 marker pairs** — Place multiple player ↔ enemy pairs to compare shots simultaneously
- **Cart type support** — Switch between **Default** (full arc) and **Malite** (apex-truncated) trajectory display modes
- **Click-through mode** — Toggle overlay passthrough so you can interact with the game beneath (`Cmd+T`), with a `Ctrl` modifier for quick temporary access
- **Snap-to-game window** — Automatically position the overlay on top of a running game window by title
- **Color-coded pairs** — Each marker pair has a distinct color; rotate palettes with one click
- **Prediction impact markers** — Shows where the zero-wind trajectory comes closest to the enemy
- **Step-distance ticks** — Optional tick marks along the trajectory at regular path-length intervals
- **Keyboard-driven controls** — Arrow keys adjust wind angle and shot angle; number keys switch wind force instantly

---

## 🏗️ Architecture

```
swift/Sources/
├── App/
│   ├── main.swift                  # Entry point — NSApplication bootstrap
│   └── AppDelegate.swift           # App lifecycle, event routing, state management
├── Models/
│   ├── CartType.swift              # Cart enum (Default, Malite)
│   ├── MarkerPair.swift            # Immutable player ↔ enemy pair with shot params
│   ├── TrajectoryPoint.swift       # Single trajectory point + TrajectoryResult
│   └── WindSettings.swift          # Wind force/angle with acceleration math
├── Physics/
│   └── TrajectoryCalculator.swift  # Euler-integration trajectory engine & power solver
├── UI/
│   ├── CircularKnob.swift          # Custom clock-face knob for wind direction
│   └── TrajectoryView.swift        # NSView rendering trajectories, markers, crosshairs
├── Utilities/
│   ├── ColorInterpolation.swift    # Color math, palettes, gradient helpers
│   └── WindowFinder.swift          # CGWindowList API — find & position game windows
└── Windows/
    ├── ControlPanelWindow.swift    # Floating panel with all parameter controls
    └── OverlayWindow.swift         # Transparent overlay window hosting TrajectoryView
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Pure AppKit (no SwiftUI)** | Direct Core Graphics rendering for minimal latency on the overlay |
| **Immutable model types** | `MarkerPair` and `WindSettings` use `with*()` copy methods for safe state updates |
| **Euler integration** | Simple, predictable physics loop with configurable time step (fine: 0.01s, coarse: 0.015s for drag performance) |
| **Linear power solver** | Scans power range to find closest trajectory approach — reliable for the game's parameter space |
| **`NSWindow.level = .floating`** | Both windows stay above all other apps without requiring accessibility hacks |

---

## 🔧 Requirements

- **macOS 13.0** (Ventura) or later
- **Swift 5.9+** / Xcode 15+
- **Screen Recording permission** — Required by `CGWindowListCopyWindowInfo` to read game window titles

---

## 🚀 Getting Started

### Build & Run (Swift Package Manager)

```bash
cd swift

# Debug build + run
swift build && swift run

# Or use the build script
./build.sh
```

### Build as .app Bundle

```bash
cd swift

# Debug .app
./build-app.sh

# Release .app
./build-app.sh release

# Run it
open .build/debug/GunboundAimAssistant.app

# Install to Applications
cp -r .build/release/GunboundAimAssistant.app /Applications/
```

### First Launch

1. macOS will prompt for **Screen Recording** permission — grant it so the app can find your game window
2. Two windows appear:
   - **Aim Controls** — floating panel with all parameters
   - **Gunbound Overlay** — transparent canvas for trajectory visualization

---

## 🎮 Usage

### Basic Workflow

1. **Launch the game** (Gunbound M, Gunbound Legend, etc.)
2. **Position the overlay** — Enter the game window title in *Window Positioning* section and click "Position Overlay"
3. **Place markers** — Drag the **player marker** (colored dot) to your tank, drag the **enemy marker** to the target
4. **Set wind** — Click a wind force button (1–12) or type the number; drag the clock-face knob to set direction
5. **Adjust shot angle** — Use the slider or `↑`/`↓` arrow keys
6. **Read the power** — The app auto-calculates optimal shot power displayed in the trajectory
7. **Enable click-through** — Press `Cmd+T` so mouse clicks pass through to the game; hold `Ctrl` to temporarily interact with the overlay

### Controls Reference

| Control | Action |
|---|---|
| `1`–`9`, `10`–`12` | Set wind force (type digits) |
| `←` / `→` | Rotate wind angle (7.5° step, +Shift = 15°) |
| `↑` / `↓` | Adjust shot angle (1° step, +Shift = 2.5°) |
| `Cmd+T` | Toggle click-through mode |
| `Ctrl` (hold) | Temporarily disable click-through for quick marker adjustments |
| `Tab` | Cycle active marker pair |
| `Esc` | Blur focused text fields |
| `Cmd+Q` | Quit |

### Multiple Marker Pairs

- Click **Add Pair** to add a second or third player ↔ enemy pair (max 3)
- Each pair has its own shot angle slider, cart type selector, and color
- Click **Rotate Colors** to cycle the color palette
- Click a marker or trajectory line to select that pair

### Cart Types

| Type | Behavior |
|---|---|
| **Default** | Full trajectory arc — power solver minimizes distance to enemy across entire path |
| **Malite** | Trajectory truncated at apex — power solver matches apex X position to enemy X position (for lob/mortar shots) |

---

## ⚙️ Physics Model

The trajectory engine uses **Euler integration** to simulate projectile motion with wind:

```
For each time step dt:
    vx += wind_accel_x * dt
    vy += wind_accel_y * dt
    vy -= gravity * dt        // 9.8 m/s²
    x  += vx * dt
    y  += vy * dt
```

**Wind acceleration** follows a smooth power-law scaling:

```
scaled_force = force^1.08 × 0.12
accel_x = scaled_force × cos(angle)
accel_y = scaled_force × sin(angle)
```

This gives wind 12 approximately 1.6× the effect of wind 6, matching the game's non-linear wind behavior.

---

## 📝 License

This project is for **educational and personal use only**. Use responsibly.
