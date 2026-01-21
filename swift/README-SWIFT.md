# Gunbound Aim Assistant - Swift/macOS Version

Native macOS application for Gunbound Mobile aim assistance with trajectory visualization.

## Overview

This is a complete Swift rewrite of the Python Tkinter version, providing:
- **Native macOS integration** - Better performance and window management
- **Pure Swift/AppKit** - No external dependencies
- **Modular architecture** - Clean, testable, maintainable code
- **Functional programming** - Pure functions for physics calculations

## Features

- ✅ Real-time trajectory calculation with wind effects
- ✅ Multiple marker pairs (up to 3 simultaneous targets)
- ✅ Transparent overlay window with click-through mode
- ✅ Circular knob for wind direction (clock-face interface)
- ✅ Auto-calculation of optimal shot power
- ✅ Global hotkeys (Cmd+T, Shift)
- ✅ Window positioning to target application
- ✅ 60 FPS rendering with performance optimization

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)
- Swift 5.9 or later

## Building

### Using Swift Package Manager

```bash
# Build the project
swift build

# Run the application
swift run

# Build for release
swift build -c release

# The executable will be at:
# .build/release/GunboundAimAssistant
```

### Using Xcode

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open GunboundAimAssistant.xcodeproj
```

Then build and run from Xcode (Cmd+R).

## Project Structure

```
GunboundAimAssistant/
├── Package.swift                      # Swift Package Manager configuration
├── Sources/
│   ├── Models/                        # Data structures (pure, immutable)
│   │   ├── WindSettings.swift         # Wind force and angle
│   │   ├── MarkerPair.swift           # Player/enemy positions
│   │   └── TrajectoryPoint.swift      # Trajectory calculation results
│   ├── Physics/                       # Pure physics calculations
│   │   └── TrajectoryCalculator.swift # Trajectory and power solver
│   ├── Utilities/                     # Helper functions
│   │   ├── ColorInterpolation.swift   # Color utilities
│   │   └── WindowFinder.swift         # macOS window detection
│   ├── UI/                            # Custom UI components
│   │   ├── CircularKnob.swift         # Circular angle selector
│   │   └── TrajectoryView.swift       # Trajectory rendering
│   ├── Windows/                       # Window management
│   │   ├── ControlPanelWindow.swift   # Main control window
│   │   └── OverlayWindow.swift        # Transparent overlay
│   └── App/                           # Application entry point
│       ├── AppDelegate.swift          # App lifecycle and coordination
│       └── main.swift                 # Entry point
└── Resources/
    └── Info.plist                     # App metadata
```

## Architecture

### Design Principles

Following the code quality standards:

1. **Modular** - Each file has a single responsibility
2. **Functional** - Pure functions for calculations (no side effects)
3. **Immutable** - Data structures use Swift structs (value types)
4. **Composable** - Small functions combined into larger ones
5. **Testable** - Pure functions are easy to test in isolation

### Data Flow

```
User Input → Control Window → AppDelegate → Physics Calculator → Trajectory View
                                    ↓
                              Update Models (immutable)
                                    ↓
                              Render Overlay
```

### Pure Functions

All physics calculations are pure functions:

```swift
// Same inputs always produce same outputs
TrajectoryCalculator.calculateTrajectory(
    startPosition: CGPoint,
    shotAngle: Double,
    shotPower: Double,
    windSettings: WindSettings,
    direction: Int
) -> TrajectoryResult
```

## Usage

### Controls

**Wind Settings:**
- Click buttons 1-12 to set wind force
- Drag circular knob to set wind direction (clock-face)

**Shot Angle:**
- Drag slider to adjust shot angle (0-90°)

**Marker Pairs:**
- Drag green marker (player position)
- Drag red marker (enemy position)
- Add/Remove pairs (up to 3)

**Overlay Controls:**
- **Cmd+T**: Toggle click-through mode
- **Hold Shift**: Temporarily disable click-through for quick adjustments

**Window Positioning:**
- Enter target window title (e.g., "Gunbound Legend")
- Set X/Y offset
- Click "Position Overlay" to snap to target window

### Click-Through Mode

When enabled, the overlay becomes transparent to mouse clicks, allowing you to interact with the game underneath while still seeing the trajectory visualization.

## Physics Model

### Trajectory Calculation

Uses Euler integration for continuous wind acceleration:

```swift
// Constants
GRAVITY = 9.8 m/s²
TIME_STEP = 0.01 seconds

// Initial velocity
v0 = power * 0.5
vx = v0 * cos(shotAngle) * direction
vy = v0 * sin(shotAngle)

// Wind acceleration
windAccel = windForce * 0.1
windAx = windAccel * cos(windAngle)
windAy = windAccel * sin(windAngle)

// Each time step:
vx += windAx * dt
vy += windAy * dt - GRAVITY * dt
x += vx * dt
y += vy * dt
```

### Power Solver

Linear search algorithm to find optimal shot power:

1. Start at power = 0
2. Calculate trajectory
3. Find closest approach to target
4. If hit or moving away from target, stop
5. Otherwise increment power and repeat

## Performance Optimizations

- **Throttled rendering**: 60 FPS cap during drag operations
- **Coarse time step**: Faster calculations while dragging (0.015s vs 0.01s)
- **Lazy updates**: Only recalculate when parameters change
- **Efficient drawing**: Direct CoreGraphics rendering

## Permissions

On first run, macOS may request permissions:

- **Accessibility**: Required for global Shift key monitoring
- **Screen Recording**: May be requested for window detection

Grant these in **System Settings → Privacy & Security**.

## Differences from Python Version

### Improvements

✅ **Native performance**: Compiled Swift vs interpreted Python
✅ **Better window management**: Native AppKit APIs
✅ **No dependencies**: Pure Swift (vs pynput, pyobjc, tkinter)
✅ **Type safety**: Swift's strong type system
✅ **Modular code**: Clean separation of concerns
✅ **Functional purity**: Testable physics calculations

### Feature Parity

All features from the Python version are implemented:
- ✅ Wind force and direction controls
- ✅ Shot angle adjustment
- ✅ Multiple marker pairs
- ✅ Click-through mode
- ✅ Global hotkeys
- ✅ Window positioning
- ✅ Trajectory visualization

## Development

### Code Style

- **Naming**: camelCase for variables/functions, PascalCase for types
- **Functions**: Verb phrases (calculateTrajectory, updateVisualization)
- **Pure functions**: No side effects, same input = same output
- **Immutability**: Use structs, create new instances instead of mutating

### Testing

Pure functions can be easily unit tested:

```swift
func testTrajectoryCalculation() {
    let result = TrajectoryCalculator.calculateTrajectory(
        startPosition: CGPoint(x: 0, y: 0),
        shotAngle: 45.0,
        shotPower: 100.0,
        windSettings: WindSettings(force: 5.0, angle: 90.0),
        direction: 1
    )
    
    XCTAssertFalse(result.points.isEmpty)
    // Add more assertions...
}
```

## Troubleshooting

### Build Errors

If you encounter build errors:

```bash
# Clean build artifacts
swift package clean

# Reset package cache
swift package reset

# Rebuild
swift build
```

### LSP Errors in Editor

The LSP errors shown during development are expected until the package is built. They will resolve after running:

```bash
swift build
```

### Window Not Appearing

If windows don't appear:
1. Check Console.app for errors
2. Ensure macOS version is 13.0+
3. Try running from terminal to see output

## License

Same as the original Python version.

## Credits

Converted from Python/Tkinter to Swift/AppKit while maintaining all functionality and improving architecture with functional programming principles.
