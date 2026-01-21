import AppKit

/// Transparent overlay window for trajectory visualization
class OverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    private let trajectoryView: TrajectoryView
    
    /// Whether click-through mode is enabled
    private(set) var isClickThroughEnabled: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // Create trajectory view
        self.trajectoryView = TrajectoryView(frame: NSRect(x: 0, y: 0, width: 1050, height: 850))
        
        // Initialize window with transparency
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 850),
            styleMask: [.titled, .closable, .resizable],
            backing: .retained,  // Use retained backing to prevent ghost artifacts
            defer: false
        )
        
        self.title = "Gunbound Overlay"
        self.isReleasedWhenClosed = false
        self.level = .statusBar
        self.hasShadow = false
        
        // Configure transparency
        self.isOpaque = false
        self.backgroundColor = .clear
        self.alphaValue = 0.9
        
        // Set content view
        self.contentView = trajectoryView
        
        // Make window ignore mouse events initially (will be toggled)
        self.ignoresMouseEvents = false
    }
    
    // MARK: - Public Methods
    
    /// Get the trajectory view for configuration
    func getTrajectoryView() -> TrajectoryView {
        return trajectoryView
    }
    
    /// Enable or disable click-through mode
    func setClickThrough(enabled: Bool) {
        isClickThroughEnabled = enabled
        self.ignoresMouseEvents = enabled
    }
    
    /// Position window relative to another window
    func positionRelativeTo(controlWindow: NSWindow) {
        let controlFrame = controlWindow.frame
        let newOrigin = CGPoint(
            x: controlFrame.origin.x + controlFrame.width,
            y: controlFrame.origin.y
        )
        self.setFrameOrigin(newOrigin)
    }
}
