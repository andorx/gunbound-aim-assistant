import AppKit

/// A circular knob control for selecting angles (0-360 degrees) with clock-face visualization
class CircularKnob: NSView {
    
    // MARK: - Properties
    
    /// Current angle in degrees (0-360)
    private(set) var angle: Double = 90.0 {
        didSet {
            needsDisplay = true
            onAngleChanged?(angle)
        }
    }
    
    /// Callback when angle changes
    var onAngleChanged: ((Double) -> Void)?
    
    /// Knob size (diameter)
    private let knobSize: CGFloat
    
    /// Radius of the circular track
    private var trackRadius: CGFloat {
        (knobSize / 2) - 10
    }
    
    /// Radius of the draggable knob
    private let knobRadius: CGFloat = 8
    
    /// Snap angle step (15 degrees = 30 minutes on clock)
    private let snapStep: Double = 15.0
    
    // MARK: - Initialization
    
    init(size: CGFloat = 150, initialAngle: Double = 90.0) {
        self.knobSize = size
        self.angle = initialAngle
        
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    // MARK: - Setup
    
    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        // Draw outer circle (track)
        context.setFillColor(NSColor(red: 0.176, green: 0.216, blue: 0.282, alpha: 1.0).cgColor)
        context.setStrokeColor(NSColor(red: 0.290, green: 0.333, blue: 0.408, alpha: 1.0).cgColor)
        context.setLineWidth(2)
        
        let trackRect = CGRect(
            x: center.x - trackRadius,
            y: center.y - trackRadius,
            width: trackRadius * 2,
            height: trackRadius * 2
        )
        context.addEllipse(in: trackRect)
        context.drawPath(using: .fillStroke)
        
        // Draw clock hour labels (12, 3, 6, 9)
        drawClockLabels(context: context, center: center)
        
        // Draw tick marks
        drawTickMarks(context: context, center: center)
        
        // Draw knob
        drawKnob(context: context, center: center)
        
        // Draw center text (clock time)
        drawCenterText(center: center)
    }
    
    private func drawClockLabels(context: CGContext, center: CGPoint) {
        let labels = [
            (angle: 90.0, text: "12"),
            (angle: 0.0, text: "3"),
            (angle: 270.0, text: "6"),
            (angle: 180.0, text: "9")
        ]
        
        let labelRadius = trackRadius - 15
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8),
            .foregroundColor: NSColor(red: 0.443, green: 0.502, blue: 0.588, alpha: 1.0)
        ]
        
        for (labelAngle, text) in labels {
            let radians = labelAngle * .pi / 180.0
            let x = center.x + labelRadius * cos(radians)
            let y = center.y + labelRadius * sin(radians)
            
            let string = NSAttributedString(string: text, attributes: attributes)
            let size = string.size()
            let point = CGPoint(x: x - size.width / 2, y: y - size.height / 2)
            
            string.draw(at: point)
        }
    }
    
    private func drawTickMarks(context: CGContext, center: CGPoint) {
        // Hour marks (every 30 degrees)
        context.setStrokeColor(NSColor(red: 0.443, green: 0.502, blue: 0.588, alpha: 1.0).cgColor)
        context.setLineWidth(2)
        
        for tickAngle in stride(from: 0.0, to: 360.0, by: 30.0) {
            let radians = tickAngle * .pi / 180.0
            let x1 = center.x + (trackRadius - 5) * cos(radians)
            let y1 = center.y + (trackRadius - 5) * sin(radians)
            let x2 = center.x + (trackRadius - 10) * cos(radians)
            let y2 = center.y + (trackRadius - 10) * sin(radians)
            
            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
        }
        context.strokePath()
        
        // Half-hour marks (every 15 degrees offset)
        context.setStrokeColor(NSColor(red: 0.290, green: 0.333, blue: 0.408, alpha: 1.0).cgColor)
        context.setLineWidth(1)
        
        for tickAngle in stride(from: 15.0, to: 360.0, by: 30.0) {
            let radians = tickAngle * .pi / 180.0
            let x1 = center.x + (trackRadius - 5) * cos(radians)
            let y1 = center.y + (trackRadius - 5) * sin(radians)
            let x2 = center.x + (trackRadius - 8) * cos(radians)
            let y2 = center.y + (trackRadius - 8) * sin(radians)
            
            context.move(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x2, y: y2))
        }
        context.strokePath()
    }
    
    private func drawKnob(context: CGContext, center: CGPoint) {
        let radians = angle * .pi / 180.0
        let knobX = center.x + (trackRadius - 20) * cos(radians)
        let knobY = center.y + (trackRadius - 20) * sin(radians)
        
        context.setFillColor(NSColor(red: 0.388, green: 0.702, blue: 0.929, alpha: 1.0).cgColor)
        context.setStrokeColor(NSColor(red: 0.192, green: 0.510, blue: 0.808, alpha: 1.0).cgColor)
        context.setLineWidth(2)
        
        let knobRect = CGRect(
            x: knobX - knobRadius,
            y: knobY - knobRadius,
            width: knobRadius * 2,
            height: knobRadius * 2
        )
        context.addEllipse(in: knobRect)
        context.drawPath(using: .fillStroke)
    }
    
    private func drawCenterText(center: CGPoint) {
        let clockText = formatClockTime(angle: angle)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor(red: 0.886, green: 0.910, blue: 0.941, alpha: 1.0)
        ]
        
        let string = NSAttributedString(string: clockText, attributes: attributes)
        let size = string.size()
        let point = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        
        string.draw(at: point)
    }
    
    // MARK: - Mouse Handling
    
    override func mouseDown(with event: NSEvent) {
        updateAngle(from: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        updateAngle(from: event)
    }
    
    private func updateAngle(from event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        let dx = location.x - center.x
        let dy = location.y - center.y
        
        // Calculate angle in degrees
        var newAngle = atan2(dy, dx) * 180.0 / .pi
        if newAngle < 0 {
            newAngle += 360.0
        }
        
        // Snap to nearest step
        let snapped = round(newAngle / snapStep) * snapStep
        angle = snapped.truncatingRemainder(dividingBy: 360.0)
    }
    
    // MARK: - Public Methods
    
    /// Set angle programmatically
    func setAngle(_ newAngle: Double) {
        angle = newAngle.truncatingRemainder(dividingBy: 360.0)
    }
    
    // MARK: - Helpers
    
    /// Convert angle to clock time string (e.g., "1", "1:30", "12")
    private func formatClockTime(angle: Double) -> String {
        // 90 degrees is 12 o'clock
        // Moving clockwise (decreasing angle in standard trig)
        let degFrom12 = (90 - angle).truncatingRemainder(dividingBy: 360.0)
        let degFrom12Positive = degFrom12 < 0 ? degFrom12 + 360 : degFrom12
        
        // 30 degrees = 1 hour
        let hoursFloat = degFrom12Positive / 30.0
        var hour = Int(hoursFloat)
        let minutePart = hoursFloat - Double(hour)
        
        // Handle 0 hour as 12
        if hour == 0 {
            hour = 12
        }
        
        // Check if it's a half hour (approx 0.5)
        if abs(minutePart - 0.5) < 0.1 {
            return "\(hour):30"
        } else {
            return "\(hour)"
        }
    }
}
