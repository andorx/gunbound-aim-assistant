import AppKit
import SwiftUI

/// Main control panel window for adjusting aim parameters
class ControlPanelWindow: NSWindow {
    
    // MARK: - UI Components
    
    private let windForceButtons: [NSButton]
    private let windAngleKnob: CircularKnob
    private let shotAngleSlider: NSSlider
    private let shotAngleLabel: NSTextField
    private let addPairButton: NSButton
    private let removePairButton: NSButton
    private let clickThroughButton: NSButton
    private let clickThroughStatusLabel: NSTextField
    private let targetWindowField: NSTextField
    private let offsetXField: NSTextField
    private let offsetYField: NSTextField
    private let positionButton: NSButton
    
    // MARK: - Callbacks
    
    var onWindForceChanged: ((Double) -> Void)?
    var onWindAngleChanged: ((Double) -> Void)?
    var onShotAngleChanged: ((Double) -> Void)?
    var onAddPair: (() -> Void)?
    var onRemovePair: (() -> Void)?
    var onToggleClickThrough: (() -> Void)?
    var onPositionOverlay: ((String, CGPoint) -> Void)?
    
    // MARK: - State
    
    private var currentWindForce: Int = 5
    private var modifierKeyPressed: Bool = false
    
    // MARK: - Initialization
    
    init() {
        // Create UI components first
        var buttons: [NSButton] = []
        for i in 1...12 {
            let button = NSButton(title: "\(i)", target: nil, action: nil)
            button.bezelStyle = .rounded
            buttons.append(button)
        }
        self.windForceButtons = buttons
        
        self.windAngleKnob = CircularKnob(size: 150, initialAngle: 90.0)
        self.shotAngleSlider = NSSlider(value: 45.0, minValue: 0.0, maxValue: 90.0, target: nil, action: nil)
        self.shotAngleLabel = NSTextField(labelWithString: "45.0°")
        self.addPairButton = NSButton(title: "Add Pair", target: nil, action: nil)
        self.removePairButton = NSButton(title: "Remove Pair", target: nil, action: nil)
        self.clickThroughButton = NSButton(title: "Enable Click-Through", target: nil, action: nil)
        self.clickThroughStatusLabel = NSTextField(labelWithString: "✗ Click-Through: Disabled")
        self.targetWindowField = NSTextField(string: "Gunbound Legend")
        self.offsetXField = NSTextField(string: "0")
        self.offsetYField = NSTextField(string: "-30")
        self.positionButton = NSButton(title: "Position Overlay", target: nil, action: nil)
        
        // Initialize window
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 670),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Aim Controls"
        self.isReleasedWhenClosed = false
        self.level = .floating
        
        setupUI()
        setupActions()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let windowFrame = frame
        let contentView = NSView(frame: windowFrame)
        self.contentView = contentView
        
        var yOffset: CGFloat = windowFrame.height - 20
        
        // Title
        let titleLabel = NSTextField(labelWithString: "Wind Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(titleLabel)
        yOffset -= 30
        
        // Wind Force Label
        let windForceLabel = NSTextField(labelWithString: "Wind Force (1-12):")
        windForceLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(windForceLabel)
        yOffset -= 30
        
        // Wind Force Buttons Grid (4 rows x 3 columns for better layout)
        let gridConfig = (
            columns: 4,
            rows: 3,
            buttonWidth: 70.0,
            buttonHeight: 32.0,
            horizontalSpacing: 0.0,
            verticalSpacing: 0.0,
            leftMargin: 10.0
        )
        
        for (index, button) in windForceButtons.enumerated() {
            let row = index / gridConfig.columns
            let col = index % gridConfig.columns
            
            let x = gridConfig.leftMargin + CGFloat(col) * (gridConfig.buttonWidth + gridConfig.horizontalSpacing)
            let y = yOffset - CGFloat(row) * (gridConfig.buttonHeight + gridConfig.verticalSpacing)
            
            button.frame = NSRect(x: x, y: y, width: gridConfig.buttonWidth, height: gridConfig.buttonHeight)
            button.bezelStyle = .rounded
            button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            contentView.addSubview(button)
        }
        yOffset -= CGFloat(gridConfig.rows) * (gridConfig.buttonHeight + gridConfig.verticalSpacing) + 10
        
        // Wind Direction Label
        let windDirLabel = NSTextField(labelWithString: "Wind Direction:")
        windDirLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(windDirLabel)
        
        // Wind Angle Knob
        windAngleKnob.frame = NSRect(x: 75, y: yOffset - 150, width: 150, height: 150)
        contentView.addSubview(windAngleKnob)
        yOffset -= 165
        
        // Shot Angle Label
        let shotAngleLabel = NSTextField(labelWithString: "Shot Angle (°):")
        shotAngleLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(shotAngleLabel)
        yOffset -= 25
        
        // Shot Angle Slider
        shotAngleSlider.frame = NSRect(x: 10, y: yOffset, width: 280, height: 25)
        contentView.addSubview(shotAngleSlider)
        yOffset -= 20
        
        // Shot Angle Value Label
        self.shotAngleLabel.alignment = .right
        self.shotAngleLabel.frame = NSRect(x: 200, y: yOffset, width: 90, height: 20)
        contentView.addSubview(self.shotAngleLabel)
        yOffset -= 25
        
        // Marker Pairs Label
        let pairsLabel = NSTextField(labelWithString: "Marker Pairs")
        pairsLabel.font = NSFont.boldSystemFont(ofSize: 10)
        pairsLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(pairsLabel)
        yOffset -= 25
        
        // Add/Remove Pair Buttons
        addPairButton.frame = NSRect(x: 0, y: yOffset, width: 145, height: 25)
        contentView.addSubview(addPairButton)
        
        removePairButton.frame = NSRect(x: 150, y: yOffset, width: 145, height: 25)
        contentView.addSubview(removePairButton)
        yOffset -= 35
        
        // Overlay Controls Label
        let overlayLabel = NSTextField(labelWithString: "Overlay Controls")
        overlayLabel.font = NSFont.boldSystemFont(ofSize: 12)
        overlayLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(overlayLabel)
        yOffset -= 25
        
        // Instructions
        let cmdTLabel = NSTextField(labelWithString: "Cmd+T: Toggle Click-Through")
        cmdTLabel.font = NSFont.boldSystemFont(ofSize: 9)
        cmdTLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 15)
        contentView.addSubview(cmdTLabel)
        yOffset -= 18
        
        let modifierKeyLabel = NSTextField(labelWithString: "Hold Ctrl: Quick Adjust Markers")
        modifierKeyLabel.font = NSFont.boldSystemFont(ofSize: 9)
        modifierKeyLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 15)
        contentView.addSubview(modifierKeyLabel)
        yOffset -= 30
        
        // Click-Through Button
        clickThroughButton.frame = NSRect(x: 0, y: yOffset, width: 300, height: 30)
        contentView.addSubview(clickThroughButton)
        yOffset -= 20
        
        // Click-Through Status
        clickThroughStatusLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        clickThroughStatusLabel.textColor = NSColor(red: 0.290, green: 0.333, blue: 0.408, alpha: 1.0)
        contentView.addSubview(clickThroughStatusLabel)
        yOffset -= 30
        
        // Window Positioning Section
        let positionLabel = NSTextField(labelWithString: "Target Window Title:")
        positionLabel.frame = NSRect(x: 10, y: yOffset, width: 280, height: 20)
        contentView.addSubview(positionLabel)
        yOffset -= 25
        
        targetWindowField.frame = NSRect(x: 10, y: yOffset, width: 280, height: 22)
        contentView.addSubview(targetWindowField)
        yOffset -= 30
        
        // Offset fields
        let xLabel = NSTextField(labelWithString: "X:")
        xLabel.frame = NSRect(x: 10, y: yOffset, width: 20, height: 20)
        contentView.addSubview(xLabel)
        
        offsetXField.frame = NSRect(x: 35, y: yOffset, width: 80, height: 22)
        contentView.addSubview(offsetXField)
        
        let yLabel = NSTextField(labelWithString: "Y:")
        yLabel.frame = NSRect(x: 145, y: yOffset, width: 20, height: 20)
        contentView.addSubview(yLabel)
        
        offsetYField.frame = NSRect(x: 170, y: yOffset, width: 80, height: 22)
        contentView.addSubview(offsetYField)
        yOffset -= 30
        
        // Position Button
        positionButton.frame = NSRect(x: 0, y: yOffset, width: 300, height: 25)
        contentView.addSubview(positionButton)
        
        // Initial button states
        updateWindForceButtons()
    }
    
    private func setupActions() {
        // Wind force buttons
        for (index, button) in windForceButtons.enumerated() {
            let level = index + 1
            button.target = self
            button.action = #selector(windForceButtonClicked(_:))
            button.tag = level
        }
        
        // Wind angle knob
        windAngleKnob.onAngleChanged = { [weak self] angle in
            self?.onWindAngleChanged?(angle)
        }
        
        // Shot angle slider
        shotAngleSlider.target = self
        shotAngleSlider.action = #selector(shotAngleSliderChanged(_:))
        
        // Pair buttons
        addPairButton.target = self
        addPairButton.action = #selector(addPairClicked)
        
        removePairButton.target = self
        removePairButton.action = #selector(removePairClicked)
        
        // Click-through button
        clickThroughButton.target = self
        clickThroughButton.action = #selector(clickThroughClicked)
        
        // Position button
        positionButton.target = self
        positionButton.action = #selector(positionButtonClicked)
    }
    
    // MARK: - Actions
    
    @objc private func windForceButtonClicked(_ sender: NSButton) {
        let level = sender.tag
        currentWindForce = level
        updateWindForceButtons()
        onWindForceChanged?(Double(level))
    }
    
    @objc private func shotAngleSliderChanged(_ sender: NSSlider) {
        let value = sender.doubleValue
        let rounded = round(value * 10) / 10
        shotAngleLabel.stringValue = String(format: "%.1f°", rounded)
        onShotAngleChanged?(rounded)
    }
    
    @objc private func addPairClicked() {
        onAddPair?()
    }
    
    @objc private func removePairClicked() {
        onRemovePair?()
    }
    
    @objc private func clickThroughClicked() {
        onToggleClickThrough?()
    }
    
    @objc private func positionButtonClicked() {
        let title = targetWindowField.stringValue
        let x = CGFloat(Int(offsetXField.stringValue) ?? 0)
        let y = CGFloat(Int(offsetYField.stringValue) ?? -30)
        onPositionOverlay?(title, CGPoint(x: x, y: y))
    }
    
    // MARK: - Public Methods
    
    func setWindForce(_ force: Double) {
        currentWindForce = Int(force)
        updateWindForceButtons()
    }
    
    func setWindAngle(_ angle: Double) {
        windAngleKnob.setAngle(angle)
    }
    
    func setShotAngle(_ angle: Double) {
        shotAngleSlider.doubleValue = angle
        shotAngleLabel.stringValue = String(format: "%.1f°", angle)
    }
    
    func updatePairButtonStates(pairCount: Int) {
        addPairButton.isEnabled = pairCount < 3
        removePairButton.isEnabled = pairCount > 1
    }
    
    func updateClickThroughUI(enabled: Bool, modifierKeyHeld: Bool) {
        modifierKeyPressed = modifierKeyHeld
        
        if modifierKeyHeld && enabled {
            clickThroughButton.title = "Disable Click-Through"
            clickThroughStatusLabel.stringValue = "⇧ Ctrl Held: Temporarily Disabled"
            clickThroughStatusLabel.textColor = NSColor(red: 0.925, green: 0.788, blue: 0.294, alpha: 1.0)
        } else if enabled {
            clickThroughButton.title = "Disable Click-Through"
            clickThroughStatusLabel.stringValue = "✓ Click-Through: Enabled"
            clickThroughStatusLabel.textColor = NSColor(red: 0.282, green: 0.733, blue: 0.471, alpha: 1.0)
        } else {
            clickThroughButton.title = "Enable Click-Through"
            clickThroughStatusLabel.stringValue = "✗ Click-Through: Disabled"
            clickThroughStatusLabel.textColor = NSColor(red: 0.290, green: 0.333, blue: 0.408, alpha: 1.0)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateWindForceButtons() {
        for (index, button) in windForceButtons.enumerated() {
            let level = index + 1
            
            if level == currentWindForce {
                // Selected button - vibrant red/orange with bold text
                button.contentTintColor = NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1.0) // Bright red
                button.bezelColor = NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 0.2)
                
                // Make the text bold and slightly larger
                button.font = NSFont.boldSystemFont(ofSize: 14)
                
                // Add a subtle shadow effect for depth
                button.shadow = NSShadow()
                button.shadow?.shadowColor = NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 0.4)
                button.shadow?.shadowOffset = NSSize(width: 0, height: -1)
                button.shadow?.shadowBlurRadius = 3
            } else {
                // Unselected buttons - neutral gray
                button.contentTintColor = NSColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)
                button.bezelColor = nil
                button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                button.shadow = nil
            }
        }
    }
}

// MARK: - SwiftUI Preview Support

#if DEBUG
import SwiftUI

/// NSViewRepresentable wrapper for ControlPanelWindow to enable Xcode Previews
struct ControlPanelWindowPreview: NSViewRepresentable {
    
    func makeNSView(context: Context) -> NSView {
        let window = ControlPanelWindow()
        
        // Configure window for preview
        window.setWindForce(5.0)
        window.setWindAngle(90.0)
        window.setShotAngle(45.0)
        window.updatePairButtonStates(pairCount: 2)
        window.updateClickThroughUI(enabled: false, modifierKeyHeld: false)
        
        // Return the content view for preview
        return window.contentView ?? NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed for static preview
    }
}

@available(macOS 13.0, *)
struct ControlPanelWindow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state preview
            ControlPanelWindowPreview()
                .frame(width: 300, height: 670)
                .previewDisplayName("Control Panel - Default")
            
            // Dark mode preview
            ControlPanelWindowPreview()
                .frame(width: 300, height: 670)
                .preferredColorScheme(.dark)
                .previewDisplayName("Control Panel - Dark Mode")
            
            // Different wind force selected
            ControlPanelWindowPreviewCustom(windForce: 12)
                .frame(width: 300, height: 670)
                .previewDisplayName("Control Panel - Max Wind")
        }
    }
}

/// Custom preview with configurable wind force
struct ControlPanelWindowPreviewCustom: NSViewRepresentable {
    let windForce: Int
    
    func makeNSView(context: Context) -> NSView {
        let window = ControlPanelWindow()
        window.setWindForce(Double(windForce))
        window.setWindAngle(90.0)
        window.setShotAngle(45.0)
        window.updatePairButtonStates(pairCount: 2)
        window.updateClickThroughUI(enabled: false, modifierKeyHeld: false)
        return window.contentView ?? NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
