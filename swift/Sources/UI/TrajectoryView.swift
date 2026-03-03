import AppKit

/// Custom view for rendering trajectory overlays with markers and paths
class TrajectoryView: NSView {
    
    // MARK: - Properties
    
    /// Marker pairs to display
    var markerPairs: [MarkerPair] = [.default] {
        didSet { 
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Index of the currently active pair
    var activePairIndex: Int = 0 {
        didSet { 
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Wind settings for trajectory calculations
    var windSettings: WindSettings = .default {
        didSet { 
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Trajectory results (one per marker pair)
    var trajectories: [TrajectoryResult] = [] {
        didSet { 
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Zero-wind trajectories for baseline comparison
    var zeroWindTrajectories: [TrajectoryResult] = [] {
        didSet { 
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }

    /// Per-pair prediction impact point (at most one per pair)
    var predictionImpactPoints: [TrajectoryPoint?] = [] {
        didSet {
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Whether to show the current wind trajectory lines
    var showTrajectory: Bool = true {
        didSet {
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Color palette offset for rotating colors (0, 1, 2 cycles through palettes)
    var colorPaletteOffset: Int = 0 {
        didSet {
            needsDisplay = true
            window?.invalidateShadow()
            window?.displayIfNeeded()
        }
    }
    
    /// Callback when a marker is dragged
    var onMarkerDragged: ((Int, MarkerRole, CGPoint) -> Void)?
    
    /// Callback when a marker pair is selected
    var onPairSelected: ((Int) -> Void)?
    
    /// Callback when trajectory line is dragged to adjust angle (pairIndex, newAngle)
    var onTrajectoryAngleDragged: ((Int, Double) -> Void)?
    
    /// Currently dragging marker
    private var draggingPair: (index: Int, role: MarkerRole)?
    
    /// Currently dragging trajectory for angle adjustment
    private var draggingTrajectoryAngle: (index: Int, initialAngle: Double, startY: CGFloat)?
    
    /// Degrees of angle change per pixel of vertical drag (drag up = higher angle)
    private let angleDragSensitivity: CGFloat = 0.1  // degrees per pixel
    
    /// Hit radius for trajectory line (pixels from line to consider a hit)
    private let trajectoryHitRadius: CGFloat = 20
    
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
        wantsLayer = true  // Don't use layer-backed rendering
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
            let colors = ColorUtilities.MarkerColors.forPair(at: index + colorPaletteOffset)
            
            // Draw zero-wind trajectory (baseline)
            if index < zeroWindTrajectories.count {
               drawGradientTrajectory(
                  context: context,
                  trajectory: zeroWindTrajectories[index],
                  startColor: colors.trajectoryStart,
                  endColor: colors.trajectoryEnd,
                  lineWidth: 2,
               )
            }
            
            // Draw current wind trajectory (if enabled)
            if showTrajectory && index < trajectories.count {
                drawTrajectory(
                    context: context,
                    trajectory: trajectories[index],
                    color: colors.zeroWind,
                    lineWidth: 1,
                    dashed: true,
                    opacity: 0.6
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

            // Draw prediction impact marker (single point per pair)
            if index < predictionImpactPoints.count, let impactPoint = predictionImpactPoints[index] {
                drawPredictionMarker(
                    context: context,
                    position: impactPoint.position,
                    colors: colors,
                    isActive: isActive
                )
            }
        }
        
        // Draw wind indicator
        drawWindIndicator(context: context)
    }
    
    private func drawTrajectory(
        context: CGContext,
        trajectory: TrajectoryResult,
        color: NSColor,
        lineWidth: CGFloat,
        dashed: Bool = false,
        opacity: CGFloat = 1,
    ) {
        guard trajectory.points.count > 1 else { return }
        
      context.setStrokeColor(color.withAlphaComponent(opacity).cgColor)
        context.setLineWidth(lineWidth)
        
        if dashed {
            context.setLineDash(phase: 0, lengths: [4, 6])
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
        lineWidth: CGFloat,
        opacity: CGFloat = 1
    ) {
        guard trajectory.points.count > 1 else { return }

        context.setLineWidth(lineWidth)
        context.setLineDash(phase: 0, lengths: [2, 4])

        for i in 0..<(trajectory.points.count - 1) {
            let progress = Double(i) / Double(trajectory.points.count - 1)
            let color = ColorUtilities.interpolate(from: startColor, to: endColor, t: progress)
                .withAlphaComponent(opacity)

            context.setStrokeColor(color.cgColor)
            context.beginPath()
            context.move(to: trajectory.points[i].position)
            context.addLine(to: trajectory.points[i + 1].position)
            context.strokePath()
        }

        context.setLineDash(phase: 0, lengths: [])
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

    private func drawPredictionMarker(
        context: CGContext,
        position: CGPoint,
        colors: ColorUtilities.MarkerColors,
        isActive: Bool
    ) {
        let radius: CGFloat = 3.5

        context.setFillColor(colors.player.withAlphaComponent(0.65).cgColor)
        context.setLineWidth(0)

        let rect = CGRect(
            x: position.x - radius,
            y: position.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.addEllipse(in: rect)
        context.drawPath(using: .fill)
    }
    
    private func drawCrosshair(context: CGContext, center: CGPoint) {
        let radius: CGFloat = 100
      let color = NSColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 0.5)
        
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
        
        let color = NSColor(red: 0.788, green: 0.165, blue: 0.165, alpha: 1.0)
        
        // Draw circle background
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.addEllipse(in: CGRect(x: center.x - 35, y: center.y - 34, width: 70, height: 70))
        context.strokePath()

        // Draw shadow circle
        context.setStrokeColor(color.darker(by: 0.35).cgColor)
        context.setLineWidth(2)
        context.addEllipse(in: CGRect(x: center.x - 36, y: center.y - 35, width: 72, height: 72))
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
        
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 2
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)

        // Draw wind force text
        let text = "\(Int(windSettings.force))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 15),
            .foregroundColor: color,
            .shadow: shadow,
        ]
        
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let textPoint = CGPoint(x: center.x - size.width / 2, y: center.y + 35)
        
        string.draw(at: textPoint)
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let hitRadius: CGFloat = 28
      
        if !event.modifierFlags.contains(.control) {
            window?.makeKeyAndOrderFront(nil)
        }
        
        // Check all pairs for hit-testing (reverse order to match visual layering)
        for (index, pair) in markerPairs.enumerated().reversed() {
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
        
        // Check trajectory lines for angle-adjust drag (use gradient trajectory for hit area)
        for (index, pair) in markerPairs.enumerated().reversed() {
            guard index < zeroWindTrajectories.count else { continue }
            let trajectory = zeroWindTrajectories[index]
            
            if distanceFromPoint(location, toPolyline: trajectory.points.map(\.position)) < trajectoryHitRadius {
                draggingTrajectoryAngle = (index, pair.shotAngle, location.y)
                onPairSelected?(index)
                return
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        if let (index, role) = draggingPair {
            onMarkerDragged?(index, role, location)
            return
        }
        
        if let (index, initialAngle, startY) = draggingTrajectoryAngle {
            // Drag up (decreasing Y in flipped coords) = increase angle
            let deltaY = startY - location.y
            let deltaAngle = Double(deltaY) * Double(angleDragSensitivity)
            var newAngle = initialAngle + deltaAngle
            newAngle = max(0, min(135, newAngle))
            
            onTrajectoryAngleDragged?(index, newAngle)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        draggingPair = nil
        draggingTrajectoryAngle = nil
    }
    
    /// Minimum distance from a point to a polyline (sequence of line segments)
    private func distanceFromPoint(_ point: CGPoint, toPolyline polyline: [CGPoint]) -> CGFloat {
        guard polyline.count >= 2 else {
            return polyline.first.map { point.distance(to: $0) } ?? .infinity
        }
        
        var minDist: CGFloat = .infinity
        for i in 0..<(polyline.count - 1) {
            let dist = distanceFromPoint(point, toSegment: (polyline[i], polyline[i + 1]))
            minDist = min(minDist, dist)
        }
        return minDist
    }
    
    /// Distance from a point to a line segment
    private func distanceFromPoint(_ point: CGPoint, toSegment segment: (CGPoint, CGPoint)) -> CGFloat {
        let (a, b) = segment
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: point.x - a.x, y: point.y - a.y)
        
        let abLenSq = ab.x * ab.x + ab.y * ab.y
        guard abLenSq > 0 else { return ap.distance(to: .zero) }
        
        var t = (ap.x * ab.x + ap.y * ab.y) / abLenSq
        t = max(0, min(1, t))
        
        let closest = CGPoint(x: a.x + t * ab.x, y: a.y + t * ab.y)
        return point.distance(to: closest)
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
