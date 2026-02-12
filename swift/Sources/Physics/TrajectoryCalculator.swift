import Foundation
import CoreGraphics

/// Pure functions for projectile trajectory calculations with wind effects
enum TrajectoryCalculator {
    
    // MARK: - Physics Constants
    
    /// Gravitational acceleration (m/s²)
    private static let gravity: Double = 9.8
    
    /// Time step for Euler integration (seconds)
    private static let timeStep: Double = 0.01
    
    /// Coarse time step for performance during dragging
    private static let timeStepCoarse: Double = 0.015
    
    /// Maximum simulation time (seconds)
    private static let maxTime: Double = 60.0
    
    /// Canvas bounds for early termination
    private static let canvasBounds = CGRect(x: -400, y: -300, width: 1450, height: 1150)
    
    // MARK: - Trajectory Calculation
    
    /// Calculate projectile trajectory with wind effect using Euler integration
    ///
    /// - Parameters:
    ///   - startPosition: Starting position in canvas coordinates
    ///   - shotAngle: Shot angle in degrees (0-90)
    ///   - shotPower: Shot power (0-400)
    ///   - windSettings: Wind configuration
    ///   - direction: Horizontal direction (1 for right, -1 for left)
    ///   - useCoarseStep: Use coarser time step for performance (default: false)
    /// - Returns: Trajectory result with points
    static func calculateTrajectory(
        startPosition: CGPoint,
        shotAngle: Double,
        shotPower: Double,
        windSettings: WindSettings,
        direction: Int,
        useCoarseStep: Bool = false
    ) -> TrajectoryResult {
        var points: [TrajectoryPoint] = []
        
        // Convert angles to radians
        let shotRadians = shotAngle * .pi / 180.0
        
        // Initial velocity (scale power to velocity)
        let v0 = shotPower * 0.5
        var vx = v0 * cos(shotRadians) * Double(direction)
        var vy = v0 * sin(shotRadians)
        
        // Wind acceleration components
        let windAccel = windSettings.accelerationComponents
        
        // Initialize position (relative to start)
        var x: Double = 0.0
        var y: Double = 0.0
        var t: Double = 0.0
        
        // Choose time step based on performance mode
        let dt = useCoarseStep ? timeStepCoarse : timeStep
        
        // Simulate until projectile goes out of bounds
        while t < maxTime {
            // Convert to canvas coordinates
            let screenX = startPosition.x + x
            let screenY = startPosition.y - y  // Physics Y goes up, canvas Y goes down
            
            // Store point
            let point = TrajectoryPoint(
                position: CGPoint(x: screenX, y: screenY),
                time: t,
                velocity: (x: vx, y: vy)
            )
            points.append(point)
            
            // Stop if projectile goes out of bounds
            if !canvasBounds.contains(point.position) {
                break
            }
            
            // Update velocities (Euler integration)
            vx += windAccel.x * dt
            vy += windAccel.y * dt
            vy -= gravity * dt  // Gravity always pulls down
            
            // Update position
            x += vx * dt
            y += vy * dt
            
            // Update time
            t += dt
        }
        
        return TrajectoryResult(points: points)
    }
    
    // MARK: - Power Solver
    
    /// Find the apex (highest point) of a trajectory
    /// - Parameter trajectory: The trajectory to analyze
    /// - Returns: The trajectory point at the apex (minimum Y in canvas coordinates), or nil if empty
    private static func findApex(in trajectory: TrajectoryResult) -> TrajectoryPoint? {
        guard !trajectory.points.isEmpty else { return nil }
        return trajectory.points.min(by: { $0.position.y < $1.position.y })
    }
    
    /// Solve for optimal shot power to hit a target
    ///
    /// Uses linear search to find the power that brings the trajectory closest to the target.
    /// For Default cart: finds power where trajectory passes closest to enemy.
    /// For Malite cart: finds power where trajectory apex X position matches enemy X position.
    ///
    /// - Parameters:
    ///   - markerPair: Player and enemy positions with shot angle
    ///   - windSettings: Wind configuration
    ///   - cartType: Cart type affecting trajectory behavior
    ///   - hitTolerance: Distance tolerance for considering a hit (pixels)
    ///   - powerStep: Resolution of power search (default: 1.0)
    ///   - maxPower: Maximum power to search (default: 400.0)
    ///   - useCoarseStep: Use coarser time step for performance
    /// - Returns: Optimal shot power
    static func solveForPower(
        markerPair: MarkerPair,
        windSettings: WindSettings,
        cartType: CartType = .default,
        hitTolerance: Double = 0.0,
        powerStep: Double = 1.0,
        maxPower: Double = 1000.0,
        useCoarseStep: Bool = false
    ) -> Double {
        var bestPower: Double = 0.0
        var minDistance = Double.infinity
        
        // Linear scan from 0 to maxPower
        var currentPower: Double = 0.0
        
        while currentPower <= maxPower {
            // Calculate trajectory with this power
            let trajectory = calculateTrajectory(
                startPosition: markerPair.playerPosition,
                shotAngle: markerPair.shotAngle,
                shotPower: currentPower,
                windSettings: windSettings,
                direction: markerPair.direction,
                useCoarseStep: useCoarseStep
            )
            
            // Calculate distance based on cart type
            let distance: Double
            switch cartType {
            case .default:
                // Find closest approach across all trajectory points
                (distance, _) = trajectory.closestApproach(to: markerPair.enemyPosition)
            case .malite:
                // Find horizontal distance between apex X and enemy X
                if let apex = findApex(in: trajectory) {
                    distance = abs(apex.position.x - markerPair.enemyPosition.x)
                } else {
                    distance = Double.infinity
                }
            }
            
            // Check for hit
            if distance <= hitTolerance {
                return currentPower
            }
            
            // Check for local minimum (closest point)
            if distance < minDistance {
                // Getting closer
                minDistance = distance
                bestPower = currentPower
            } else if distance > minDistance + 1.0 {
                // Passed the closest point and moving away
                break
            }
            
            currentPower += powerStep
        }
        
        return bestPower
    }
    
    // MARK: - Batch Calculations
    
    /// Calculate trajectories for multiple marker pairs
    ///
    /// - Parameters:
    ///   - markerPairs: Array of marker pairs
    ///   - windSettings: Wind configuration
    ///   - useCoarseStep: Use coarser time step for performance
    /// - Returns: Array of trajectory results (same order as input)
    static func calculateTrajectories(
        markerPairs: [MarkerPair],
        windSettings: WindSettings,
        useCoarseStep: Bool = false
    ) -> [TrajectoryResult] {
        markerPairs.map { pair in
            calculateTrajectory(
                startPosition: pair.playerPosition,
                shotAngle: pair.shotAngle,
                shotPower: pair.shotPower,
                windSettings: windSettings,
                direction: pair.direction,
                useCoarseStep: useCoarseStep
            )
        }
    }
    
    /// Solve for optimal power for multiple marker pairs
    ///
    /// - Parameters:
    ///   - markerPairs: Array of marker pairs
    ///   - windSettings: Wind configuration
    ///   - cartType: Cart type affecting trajectory behavior
    ///   - useCoarseStep: Use coarser time step for performance
    /// - Returns: Array of optimal powers (same order as input)
    static func solveForPowers(
        markerPairs: [MarkerPair],
        windSettings: WindSettings,
        cartType: CartType = .default,
        useCoarseStep: Bool = false
    ) -> [Double] {
        markerPairs.map { pair in
            solveForPower(
                markerPair: pair,
                windSettings: windSettings,
                cartType: cartType,
                useCoarseStep: useCoarseStep
            )
        }
    }
}
