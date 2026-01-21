import AppKit

/// Custom view for rendering trajectory overlays with markers and paths
class TrajectoryView: NSView {
    
    // MARK: - Properties
    
    /// Marker pairs to display
    var markerPairs: [MarkerPair] = [.default] {
        didSet { needsDisplay = true }
    }
    
    /// Index of the currently active pair
    var activePairIndex: Int = 0 {
        didSet { needsDisplay = true }
    }
    
    /// Wind settings for trajectory calculations
    var windSettings: WindSettings = .default {
        didSet { needsDisplay = true }
    }
    
    /// Trajectory results (one per marker pair)
    var trajectories: [TrajectoryResult] = [] {
        didSet { needsDisplay = true }
    }
    
    /// Zero-wind trajectories for baseline comparison
    var zeroWindTrajectories: [TrajectoryResult] = [] {
        didSet { needsDisplay = true }
    }
    
    /// Callback when a marker is dragged
    var onMarkerDragged: ((Int, MarkerRole, CGPoint) -> Void)?
    
    /// Callback when a marker pair is selected
    var onPairSelected: ((Int) -> Void)?
    
    /// Currently dragging marker
    private var draggingPair: (index: Int, role: MarkerRole)?
    
    // MARK: - Marker Role
    
    enum MarkerRole {
        case player
        case enemy
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    // Use flipped coordinates (top-left origin) to match Python version
    override var isFlipped: Bool {
        return true
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw each marker pair
        for (index, pair) in markerPairs.enumerated() {
            let isActive = (index == activePairIndex)
            let colors = ColorUtilities.MarkerColors.forPair(at: index)
            
            // Draw zero-wind trajectory (baseline)
            if index < zeroWindTrajectories.count {
                drawTrajectory(
                    context: context,
                    trajectory: zeroWindTrajectories[index],
                    color: colors.zeroWind,
                    lineWidth: isActive ? 2 : 1,
                    dashed: true
                )
            }
            
            // Draw current wind trajectory
            if index < trajectories.count {
                drawGradientTrajectory(
                    context: context,
                    trajectory: trajectories[index],
                    startColor: colors.trajectoryStart,
                    endColor: colors.trajectoryEnd,
                    lineWidth: isActive ? 2 : 1
                )
            }
            
            // Draw crosshair around enemy
            drawCrosshair(context: context, center: pair.enemyPosition)
            
            // Draw markers
            drawMarker(
                context: context,
                position: pair.playerPosition,
                color: colors.player,
                isActive: isActive
            )
            
            drawMarker(
                context: context,
                position: pair.enemyPosition,
                color: colors.enemy,
                isActive: isActive
            )
        }
        
        // Draw wind indicator
        drawWindIndicator(context: context)
    }
    
    private func drawTrajectory(
        context: CGContext,
        trajectory: TrajectoryResult,
        color: NSColor,
        lineWidth: CGFloat,
        dashed: Bool = false
    ) {
        guard trajectory.points.count > 1 else { return }
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        
        if dashed {
            context.setLineDash(phase: 0, lengths: [6, 4])
        }
        
        context.beginPath()
        context.move(to: trajectory.points[0].position)
        
        for point in trajectory.points.dropFirst() {
            context.addLine(to: point.position)
        }
        
        context.strokePath()
        
        if dashed {
            context.setLineDash(phase: 0, lengths: [])
        }
    }
    
    private func drawGradientTrajectory(
        context: CGContext,
        trajectory: TrajectoryResult,
        startColor: NSColor,
        endColor: NSColor,
        lineWidth: CGFloat
    ) {
        guard trajectory.points.count > 1 else { return }
        
        context.setLineWidth(lineWidth)
        
        for i in 0..<(trajectory.points.count - 1) {
            let progress = Double(i) / Double(trajectory.points.count - 1)
            let color = ColorUtilities.interpolate(from: startColor, to: endColor, t: progress)
            
            context.setStrokeColor(color.cgColor)
            context.beginPath()
            context.move(to: trajectory.points[i].position)
            context.addLine(to: trajectory.points[i + 1].position)
            context.strokePath()
        }
    }
    
    private func drawMarker(
        context: CGContext,
        position: CGPoint,
        color: NSColor,
        isActive: Bool
    ) {
        let radius: CGFloat = isActive ? 7 : 5
        let lineWidth: CGFloat = isActive ? 3 : 2
        
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.darker(by: 0.3).cgColor)
        context.setLineWidth(lineWidth)
        
        let rect = CGRect(
            x: position.x - radius,
            y: position.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        
        context.addEllipse(in: rect)
        context.drawPath(using: .fillStroke)
    }
    
    private func drawCrosshair(context: CGContext, center: CGPoint) {
        let radius: CGFloat = 100
        let color = NSColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 1.0)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [2, 4])
        
        // Horizontal line
        context.beginPath()
        context.move(to: CGPoint(x: center.x - radius, y: center.y))
        context.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        context.strokePath()
        
        // Vertical line
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - radius))
        context.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.strokePath()
        
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private func drawWindIndicator(context: CGContext) {
        let center = CGPoint(x: bounds.midX, y: 72)
        let arrowLength: CGFloat = 25
        
        // Calculate arrow end point
        let radians = windSettings.angle * .pi / 180.0
        let endX = center.x + arrowLength * cos(radians)
        let endY = center.y - arrowLength * sin(radians)  // Negate Y for flipped coordinates
        
        let color = NSColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1.0)
        
        // Draw circle background
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.addEllipse(in: CGRect(x: center.x - 35, y: center.y - 35, width: 70, height: 70))
        context.strokePath()
        
        // Draw arrow
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.beginPath()
        context.move(to: center)
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.strokePath()
        
        // Draw arrowhead
        let arrowSize: CGFloat = 8
        let arrowAngle = atan2(endY - center.y, endX - center.x)
        
        let arrowPoint1 = CGPoint(
            x: endX - arrowSize * cos(arrowAngle - .pi / 6),
            y: endY - arrowSize * sin(arrowAngle - .pi / 6)
        )
        let arrowPoint2 = CGPoint(
            x: endX - arrowSize * cos(arrowAngle + .pi / 6),
            y: endY - arrowSize * sin(arrowAngle + .pi / 6)
        )
        
        context.beginPath()
        context.move(to: arrowPoint1)
        context.addLine(to: CGPoint(x: endX, y: endY))
        context.addLine(to: arrowPoint2)
        context.strokePath()
        
        // Draw wind force text
        let text = "Wind: \(Int(windSettings.force))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: color
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let textPoint = CGPoint(x: center.x - size.width / 2, y: center.y + 50)
        
        string.draw(at: textPoint)
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let hitRadius: CGFloat = 20
        
        // Check all pairs for hit-testing
        for (index, pair) in markerPairs.enumerated() {
            // Check player marker
            if location.distance(to: pair.playerPosition) < hitRadius {
                draggingPair = (index, .player)
                onPairSelected?(index)
                return
            }
            
            // Check enemy marker
            if location.distance(to: pair.enemyPosition) < hitRadius {
                draggingPair = (index, .enemy)
                onPairSelected?(index)
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let (index, role) = draggingPair else { return }
        
        let location = convert(event.locationInWindow, from: nil)
        onMarkerDragged?(index, role, location)
    }
    
    override func mouseUp(with event: NSEvent) {
        draggingPair = nil
    }
}

// MARK: - Helper Extensions

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private extension NSColor {
    func darker(by factor: CGFloat) -> NSColor {
        guard let rgb = usingColorSpace(.deviceRGB) else { return self }
        
        return NSColor(
            red: max(0, rgb.redComponent - factor),
            green: max(0, rgb.greenComponent - factor),
            blue: max(0, rgb.blueComponent - factor),
            alpha: rgb.alphaComponent
        )
    }
}
