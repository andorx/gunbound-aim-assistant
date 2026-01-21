import Foundation

/// A single point in a projectile trajectory
struct TrajectoryPoint {
    /// Position in canvas coordinates
    let position: CGPoint
    
    /// Time since launch in seconds
    let time: Double
    
    /// Velocity components at this point (m/s)
    let velocity: (x: Double, y: Double)
    
    /// Create a trajectory point
    init(position: CGPoint, time: Double, velocity: (x: Double, y: Double)) {
        self.position = position
        self.time = time
        self.velocity = velocity
    }
    
    /// Distance from this point to a target position
    func distance(to target: CGPoint) -> Double {
        let dx = position.x - target.x
        let dy = position.y - target.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// Result of a trajectory calculation
struct TrajectoryResult {
    /// Array of points along the trajectory path
    let points: [TrajectoryPoint]
    
    /// Closest distance achieved to target (if applicable)
    let closestDistance: Double?
    
    /// Whether the trajectory hit the target within tolerance
    let isHit: Bool
    
    /// Empty trajectory result
    static let empty = TrajectoryResult(points: [], closestDistance: nil, isHit: false)
    
    /// Create trajectory result
    init(points: [TrajectoryPoint], closestDistance: Double? = nil, isHit: Bool = false) {
        self.points = points
        self.closestDistance = closestDistance
        self.isHit = isHit
    }
    
    /// Calculate closest approach to a target point
    func closestApproach(to target: CGPoint) -> (distance: Double, point: TrajectoryPoint?) {
        guard !points.isEmpty else {
            return (Double.infinity, nil)
        }
        
        var minDistance = Double.infinity
        var closestPoint: TrajectoryPoint?
        
        for point in points {
            let dist = point.distance(to: target)
            if dist < minDistance {
                minDistance = dist
                closestPoint = point
            }
        }
        
        return (minDistance, closestPoint)
    }
}
