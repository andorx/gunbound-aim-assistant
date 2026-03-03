import Foundation

/// Represents a player-enemy marker pair with associated shot parameters
struct MarkerPair {
    /// Player position in canvas coordinates
    var playerPosition: CGPoint
    
    /// Enemy position in canvas coordinates
    var enemyPosition: CGPoint
    
    /// Shot angle in degrees (0-135, where 0 is horizontal, 90 is vertical, and >90 tilts back toward the player)
    var shotAngle: Double
    
    /// Calculated shot power (0-400)
    var shotPower: Double
    
    /// Cart type used for this marker pair
    var cartType: CartType
    
    /// Default marker pair
    static let `default` = MarkerPair(
        playerPosition: CGPoint(x: 200, y: 600),
        enemyPosition: CGPoint(x: 850, y: 600),
        shotAngle: 45.0,
        shotPower: 0.0,
        cartType: .default
    )
    
    /// Create a marker pair with validation
    init(playerPosition: CGPoint, enemyPosition: CGPoint, shotAngle: Double, shotPower: Double, cartType: CartType = .default) {
        self.playerPosition = playerPosition
        self.enemyPosition = enemyPosition
        self.shotAngle = max(0.0, min(135.0, shotAngle))
        self.shotPower = max(0.0, min(400.0, shotPower))
        self.cartType = cartType
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
            shotPower: shotPower,
            cartType: cartType
        )
    }
    
    /// Create a copy with updated enemy position
    func withEnemyPosition(_ position: CGPoint) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: position,
            shotAngle: shotAngle,
            shotPower: shotPower,
            cartType: cartType
        )
    }
    
    /// Create a copy with updated shot angle
    func withShotAngle(_ angle: Double) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: enemyPosition,
            shotAngle: angle,
            shotPower: shotPower,
            cartType: cartType
        )
    }
    
    /// Create a copy with updated shot power
    func withShotPower(_ power: Double) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: enemyPosition,
            shotAngle: shotAngle,
            shotPower: power,
            cartType: cartType
        )
    }
    
    /// Create a copy with updated cart type
    func withCartType(_ cartType: CartType) -> MarkerPair {
        MarkerPair(
            playerPosition: playerPosition,
            enemyPosition: enemyPosition,
            shotAngle: shotAngle,
            shotPower: shotPower,
            cartType: cartType
        )
    }
}
