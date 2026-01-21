import Foundation

/// Immutable wind configuration for trajectory calculations
struct WindSettings {
    /// Wind force on Gunbound scale (1-12)
    let force: Double
    
    /// Wind direction in degrees (0-360, where 0° is East, 90° is North)
    let angle: Double
    
    /// Default wind settings (force 5, angle 90° pointing North)
    static let `default` = WindSettings(force: 5.0, angle: 90.0)
    
    /// Create wind settings with validation
    init(force: Double, angle: Double) {
        self.force = max(1.0, min(12.0, force))
        self.angle = angle.truncatingRemainder(dividingBy: 360.0)
    }
    
    /// Wind acceleration components in m/s²
    var accelerationComponents: (x: Double, y: Double) {
        let windAccel = force * 0.1
        let radians = angle * .pi / 180.0
        return (
            x: windAccel * cos(radians),
            y: windAccel * sin(radians)
        )
    }
}
