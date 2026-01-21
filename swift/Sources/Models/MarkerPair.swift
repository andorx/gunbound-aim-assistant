import Foundation

/// Represents a player-enemy marker pair with associated shot parameters
struct MarkerPair {
    /// Player position in canvas coordinates
    var playerPosition: CGPoint
    
    /// Enemy position in canvas coordinates
    var enemyPosition: CGPoint
    
    /// Shot angle in degrees (0-90, where 0 is horizontal, 90 is vertical)
    var shotAngle: Double
    
    /// Calculated shot power (0-400)
    var shotPower: Double
    
    /// Default marker pair
    static let `default` = MarkerPair(
        playerPosition: CGPoint(x: 200, y: 600),
        enemyPosition: CGPoint(x: 850, y: 600),
        shotAngle: 45.0,
        shotPower: 0.0
    )
    
    /// Create a marker pair with validation
    init(playerPosition: CGPoint, enemyPosition: CGPoint, shotAngle: Double, shotPower: Double) {
        self.playerPosition = playerPosition
        self.enemyPosition = enemyPosition
        self.shotAngle = max(0.0, min(90.0, shotAngle))
        self.shotPower = max(0.0, min(400.0, shotPower))
    }
    
    /// Horizontal direction from player to enemy (1 for right, -1 for left)
    var direction: Int {
        enemyPosition.x >= playerPosition.x ? 1 : -1
    }
    
    /// Distance between player and enemy in pixels
    var distance: Double {
        let dx = enemyPosition.x - playerPosition.x
        let dy = enemyPosition.y - playerPosition.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Create a copy with updated player position
    func withPlayerPosition(_ position: CGPoint) -> MarkerPair {
        MarkerPair(
            playerPosition: position,
            enemyPosition: enemyPosition,
            shotAngle: shotAngle,
            shotPower: shotPower
        )
    }
    
    /// Create a copy with updated enemy position
    func withEnemyPosition(_ position: CGPoint) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: position,
            shotAngle: shotAngle,
            shotPower: shotPower
        )
    }
    
    /// Create a copy with updated shot angle
    func withShotAngle(_ angle: Double) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: enemyPosition,
            shotAngle: angle,
            shotPower: shotPower
        )
    }
    
    /// Create a copy with updated shot power
    func withShotPower(_ power: Double) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: enemyPosition,
            shotAngle: shotAngle,
            shotPower: power
        )
    }
}
