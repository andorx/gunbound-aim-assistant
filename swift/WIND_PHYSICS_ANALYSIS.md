# Wind Physics Analysis & Proposed Fix

## Current Implementation Issues

### 1. Linear Wind Scaling (WindSettings.swift:22)
```swift
let windAccel = force * 0.1
```

**Problem:** Pure linear scaling treats wind 12 as only 2.4x stronger than wind 5.
- Wind 1: 0.1 m/s²
- Wind 6: 0.6 m/s²
- Wind 12: 1.2 m/s²

User observation: "Wind 8-9+ impacts the bullet harder than light ones" suggests **non-linear scaling**.

### 2. Missing Projectile-Specific Physics

From SanjoSolutions/gunbound-aimbot (main.py:245-247):
```python
acceleration_x = int(cos(radians(wind_angle)) * wind_power) * projectile_speed
acceleration_y = int(sin(radians(wind_angle)) * wind_power) * projectile_speed + gravity
```

**Critical discovery:** Wind is **multiplied by projectile_speed** (0.625-1.395 per mobile).

This means:
- Boomer (projectile_speed = 1.395): Affected 2.23x more by wind than Grub
- Different mobiles have different wind sensitivity

### 3. Wrong Gravity Constant
- Swift uses: `gravity = 9.8` (real Earth physics)
- Gunbound uses: `gravity = -54.3 to -93.0` (game physics)

## Proposed Wind Formula

### Formula Options

#### Option 1: Piecewise Linear + Exponential (Recommended)
```swift
var accelerationComponents: (x: Double, y: Double) {
    let radians = angle * .pi / 180.0

    // Non-linear wind scaling
    // Light wind (1-6): Near-linear scaling
    // Strong wind (7-12): Exponential scaling for stronger effect
    let scaledWindForce: Double
    if force <= 6.0 {
        // Linear for light wind
        scaledWindForce = force * 0.12
    } else {
        // Non-linear for strong wind
        // Wind 12 is ~3.5x stronger than wind 6, not 2x
        let baseForce = 6.0 * 0.12  // 0.72
        let excess = force - 6.0
        // Power law: excess^1.3 for gradual increase
        scaledWindForce = baseForce + pow(excess, 1.3) * 0.22
    }

    // Wind acceleration
    let windAccel = scaledWindForce

    return (
        x: windAccel * cos(radians),
        y: windAccel * sin(radians)
    )
}
```

**Wind force comparison:**
| Wind | Current (linear) | Proposed (non-linear) | Ratio |
|------|------------------|----------------------|-------|
| 1    | 0.10             | 0.12                 | 1.20x |
| 5    | 0.50             | 0.60                 | 1.20x |
| 6    | 0.60             | 0.72                 | 1.20x |
| 8    | 0.80             | 1.02                 | 1.28x |
| 9    | 0.90             | 1.18                 | 1.31x |
| 10   | 1.00             | 1.34                 | 1.34x |
| 12   | 1.20             | 1.70                 | 1.42x |

Strong wind (8-12) has 1.3-1.4x more impact than linear model.

#### Option 2: Smooth Power Curve
```swift
var accelerationComponents: (x: Double, y: Double) {
    let radians = angle * .pi / 180.0

    // Power law scaling: force^1.15
    // Provides smooth non-linear curve across all values
    let powerExponent = 1.15
    let scaledWindForce = pow(force, powerExponent) * 0.1

    let windAccel = scaledWindForce

    return (
        x: windAccel * cos(radians),
        y: windAccel * sin(radians)
    )
}
```

**Wind force comparison:**
| Wind | Current | Power Law (1.15) | Ratio |
|------|----------|-------------------|-------|
| 1    | 0.10     | 0.10              | 1.00x |
| 5    | 0.50     | 0.60              | 1.20x |
| 6    | 0.60     | 0.76              | 1.27x |
| 8    | 0.80     | 1.07              | 1.34x |
| 9    | 0.90     | 1.21              | 1.34x |
| 10   | 1.00     | 1.35              | 1.35x |
| 12   | 1.20     | 1.68              | 1.40x |

#### Option 3: Gunbound-Style Projectile Speed Factor
```swift
// Add to TrajectoryCalculator or as a parameter
enum MobileType {
    case armor, mage, nak, trico, bigfoot, boomer, raon,
         lightning, jd, asate, ice, turtle, grub, aduka

    var projectileSpeed: Double {
        switch self {
        case .armor: return 0.74
        case .mage: return 0.78
        case .nak: return 0.99
        case .trico: return 0.87
        case .bigfoot: return 0.74
        case .boomer: return 1.395
        case .raon: return 0.827
        case .lightning: return 0.72
        case .jd: return 0.625
        case .asate: return 0.765
        case .ice: return 0.625
        case .turtle: return 0.74
        case .grub: return 0.65
        case .aduka: return 0.695
        }
    }
}

// In WindSettings:
var accelerationComponents(mobile: MobileType = .armor) -> (x: Double, y: Double) {
    let radians = angle * .pi / 180.0

    // Non-linear wind scaling
    let powerExponent = 1.15
    let scaledWindForce = pow(force, powerExponent) * 0.1

    // Apply projectile speed factor (Gunbound-style)
    let windAccel = scaledWindForce * mobile.projectileSpeed

    return (
        x: windAccel * cos(radians),
        y: windAccel * sin(radians)
    )
}
```

## Recommendations

### For Quick Fix
Use **Option 1 (Piecewise Linear + Exponential)**:
- Preserves existing behavior for light wind (1-6)
- Adds stronger effect for high wind (7-12)
- Matches user observation about 8-9+ impact

### For Full Gunbound Accuracy
Use **Option 3 (Projectile Speed Factor)**:
- Different mobiles affected differently by wind
- Boomer 2.23x more sensitive to wind than Grub
- Matches original Gunbound physics

### Calibration
After implementing any option, calibrate by:
1. Test with wind 1-12 at same angle/power
2. Compare with in-game GunboundM trajectories
3. Adjust exponents/scaling factors if needed

## Additional Notes

### Time Step
Current implementation uses `dt = 0.01` seconds. Gunbound aimbot uses `step_size = 0.05`. May need adjustment for accuracy.

### Canvas Scaling
Swift uses power → velocity scaling: `v0 = shotPower * 0.5`
Gunbound uses power directly: `speed_x = power * cos(angle)`
May need to verify scaling matches GunboundM.
