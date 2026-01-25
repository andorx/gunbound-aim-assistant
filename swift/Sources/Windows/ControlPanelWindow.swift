import AppKit
import SwiftUI

/// Custom content view that accepts first responder to allow blurring text fields
private class ClickableContentView: NSView {
    override var acceptsFirstResponder: Bool { true }
    
    override func mouseDown(with event: NSEvent) {
        // Make this view the first responder to blur any focused text field
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

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
    private let showTrajectoryCheckbox: NSButton
    private let rotateColorsButton: NSButton
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
    var onToggleTrajectory: ((Bool) -> Void)?
    var onRotateColors: (() -> Void)?
    var onPositionOverlay: ((String, CGPoint) -> Void)?
    
    // MARK: - State
    
    private var currentWindForce: Int = 5
    private var modifierKeyPressed: Bool = false
    private var windForceInputBuffer: String = ""
    private var inputCommitTimer: Timer?
    private var currentColorPalette: Int = 0
    
    // MARK: - Initialization
    
    init() {
        // Create UI components first
        var buttons: [NSButton] = []
        for i in 1...12 {
            let button = NSButton(title: "\(i)", target: nil, action: nil)
            button.bezelStyle = .regularSquare
            buttons.append(button)
        }
        self.windForceButtons = buttons
        
        self.windAngleKnob = CircularKnob(size: 180, initialAngle: 90.0)
        self.shotAngleSlider = NSSlider(value: 45.0, minValue: 0.0, maxValue: 90.0, target: nil, action: nil)
        self.shotAngleLabel = NSTextField(labelWithString: "45.0°")
        self.addPairButton = NSButton(title: "Add Pair", target: nil, action: nil)
        self.removePairButton = NSButton(title: "Remove Pair", target: nil, action: nil)
        self.clickThroughButton = NSButton(title: "Enable Click-Through", target: nil, action: nil)
        self.clickThroughStatusLabel = NSTextField(labelWithString: "✗ Click-Through: Disabled")
        self.showTrajectoryCheckbox = NSButton(checkboxWithTitle: "Show Prediction Lines", target: nil, action: nil)
        self.rotateColorsButton = NSButton(title: "Rotate Colors", target: nil, action: nil)
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
    
    // MARK: - UI Setup Helper Methods
    
    /// Creates a section title label with bold font
    private func makeSectionTitle(_ text: String, size: CGFloat = 12) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: size)
        return label
    }
    
    /// Creates a regular label
    private func makeLabel(_ text: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        return label
    }
    
    /// Creates a horizontal stack view with specified views and spacing
    private func makeHorizontalStack(
        views: [NSView],
        spacing: CGFloat = 8,
        distribution: NSStackView.Distribution = .fill
    ) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.distribution = distribution
        stack.alignment = .centerY
        return stack
    }
    
    /// Creates a vertical stack view with specified views and spacing
    private func makeVerticalStack(
        views: [NSView],
        spacing: CGFloat = 8,
        alignment: NSLayoutConstraint.Attribute = .leading
    ) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.alignment = alignment
        return stack
    }
    
    /// Creates the wind force buttons grid (3 rows x 4 columns), centered in a container
    private func makeWindForceButtonsGrid() -> NSView {
        let buttonWidth: CGFloat = 60
        let buttonHeight: CGFloat = 28
        
        // Configure all buttons
        for button in windForceButtons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .regularSquare
            button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            button.isBordered = true
            
            // Lower content hugging priority so height constraint takes precedence
            button.setContentHuggingPriority(.defaultLow, for: .vertical)
            button.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: buttonWidth),
                button.heightAnchor.constraint(equalToConstant: buttonHeight)
            ])
        }
        
        // Create 3 rows of 4 buttons each
        var rows: [NSStackView] = []
        for rowIndex in 0..<3 {
            let startIndex = rowIndex * 4
            let endIndex = min(startIndex + 4, windForceButtons.count)
            let rowButtons = Array(windForceButtons[startIndex..<endIndex])
            let row = makeHorizontalStack(views: rowButtons, spacing: 10, distribution: .equalSpacing)
            rows.append(row)
        }
        
        let grid = makeVerticalStack(views: rows, spacing: 5, alignment: .centerX)
        grid.translatesAutoresizingMaskIntoConstraints = false
        
        // Wrap grid in a container to center it within the full width
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(grid)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 280),
            grid.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            grid.topAnchor.constraint(equalTo: container.topAnchor),
            grid.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    /// Creates a labeled text field row
    private func makeLabeledField(label: String, field: NSTextField, labelWidth: CGFloat = 20) -> NSStackView {
        let labelView = makeLabel(label)
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true
        
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        
        return makeHorizontalStack(views: [labelView, field], spacing: 5)
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Create the main vertical stack view
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 10
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // === Wind Settings Section ===
        let windTitle = makeSectionTitle("Wind Settings")
        mainStack.addArrangedSubview(windTitle)
        
        let buttonsGrid = makeWindForceButtonsGrid()
        mainStack.addArrangedSubview(buttonsGrid)
        
        // === Wind Direction Section ===
        let windDirLabel = makeLabel("Wind Direction:")
        mainStack.addArrangedSubview(windDirLabel)
        
        // Center the knob using a container
        let knobContainer = NSView()
        knobContainer.translatesAutoresizingMaskIntoConstraints = false
        windAngleKnob.translatesAutoresizingMaskIntoConstraints = false
        knobContainer.addSubview(windAngleKnob)
        
        NSLayoutConstraint.activate([
            knobContainer.widthAnchor.constraint(equalToConstant: 280),
            knobContainer.heightAnchor.constraint(equalToConstant: 150),
            windAngleKnob.centerXAnchor.constraint(equalTo: knobContainer.centerXAnchor),
            windAngleKnob.centerYAnchor.constraint(equalTo: knobContainer.centerYAnchor),
            windAngleKnob.widthAnchor.constraint(equalToConstant: 150),
            windAngleKnob.heightAnchor.constraint(equalToConstant: 150)
        ])
      
        mainStack.addArrangedSubview(knobContainer)
        
        // === Shot Angle Section ===
        let shotAngleTitleLabel = makeLabel("Shot Angle (°):")
        mainStack.addArrangedSubview(shotAngleTitleLabel)
        
        shotAngleSlider.translatesAutoresizingMaskIntoConstraints = false
        shotAngleSlider.widthAnchor.constraint(equalToConstant: 280).isActive = true
        mainStack.addArrangedSubview(shotAngleSlider)
        
        shotAngleLabel.alignment = .right
        shotAngleLabel.translatesAutoresizingMaskIntoConstraints = false
        shotAngleLabel.widthAnchor.constraint(equalToConstant: 280).isActive = true
        mainStack.addArrangedSubview(shotAngleLabel)
        
        // === Marker Pairs Section ===
        let pairsLabel = makeSectionTitle("Marker Pairs", size: 10)
        mainStack.addArrangedSubview(pairsLabel)
        
        addPairButton.translatesAutoresizingMaskIntoConstraints = false
        removePairButton.translatesAutoresizingMaskIntoConstraints = false
        addPairButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        removePairButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        
        let pairButtonsRow = makeHorizontalStack(views: [addPairButton, removePairButton], spacing: 8)
        mainStack.addArrangedSubview(pairButtonsRow)
        
        // === Overlay Controls Section ===
        let overlayLabel = makeSectionTitle("Overlay Controls")
        mainStack.addArrangedSubview(overlayLabel)
        
        let cmdTLabel = makeLabel("Cmd+T: Toggle Click-Through", size: 9, bold: true)
        mainStack.addArrangedSubview(cmdTLabel)
        
        let modifierKeyLabel = makeLabel("Hold Ctrl: Quick Adjust Markers", size: 9, bold: true)
        mainStack.addArrangedSubview(modifierKeyLabel)
        
        clickThroughButton.translatesAutoresizingMaskIntoConstraints = false
        clickThroughButton.widthAnchor.constraint(equalToConstant: 280).isActive = true
        mainStack.addArrangedSubview(clickThroughButton)
        
        clickThroughStatusLabel.textColor = NSColor(red: 0.290, green: 0.333, blue: 0.408, alpha: 1.0)
        mainStack.addArrangedSubview(clickThroughStatusLabel)
        
        // Trajectory toggle
        showTrajectoryCheckbox.state = .on  // Default to showing trajectory
        mainStack.addArrangedSubview(showTrajectoryCheckbox)
        
        // Color rotation button and label
        rotateColorsButton.translatesAutoresizingMaskIntoConstraints = false
        rotateColorsButton.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let colorRow = makeHorizontalStack(views: [rotateColorsButton], spacing: 10)
        mainStack.addArrangedSubview(colorRow)
        
        // === Window Positioning Section ===
        let positionLabel = makeLabel("Target Window Title:")
        mainStack.addArrangedSubview(positionLabel)
        
        targetWindowField.translatesAutoresizingMaskIntoConstraints = false
        targetWindowField.widthAnchor.constraint(equalToConstant: 280).isActive = true
        mainStack.addArrangedSubview(targetWindowField)
        
        // Offset fields row
        let xFieldRow = makeLabeledField(label: "X:", field: offsetXField)
        let yFieldRow = makeLabeledField(label: "Y:", field: offsetYField)
        let offsetRow = makeHorizontalStack(views: [xFieldRow, yFieldRow], spacing: 20)
        mainStack.addArrangedSubview(offsetRow)
        
        positionButton.translatesAutoresizingMaskIntoConstraints = false
        positionButton.widthAnchor.constraint(equalToConstant: 280).isActive = true
        mainStack.addArrangedSubview(positionButton)
        
        // === Setup Content View with Main Stack ===
        let containerView = ClickableContentView()
        containerView.addSubview(mainStack)
        self.contentView = containerView
        
        // Pin main stack to content view with padding and fixed width
        let contentWidth: CGFloat = 280 // 300 window width - 10 left - 10 right padding
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            mainStack.widthAnchor.constraint(equalToConstant: contentWidth),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -10)
        ])
        
        // Force layout and resize window to fit content
        containerView.layoutSubtreeIfNeeded()
        let fittingSize = mainStack.fittingSize
        self.setContentSize(NSSize(width: contentWidth + 20, height: fittingSize.height + 25))
        
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
        
        // Trajectory checkbox
        showTrajectoryCheckbox.target = self
        showTrajectoryCheckbox.action = #selector(trajectoryCheckboxChanged(_:))
        
        // Rotate colors button
        rotateColorsButton.target = self
        rotateColorsButton.action = #selector(rotateColorsClicked)
        
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
    
    @objc private func trajectoryCheckboxChanged(_ sender: NSButton) {
        let isChecked = sender.state == .on
        onToggleTrajectory?(isChecked)
    }
    
    @objc private func rotateColorsClicked() {
        onRotateColors?()
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
    
    func setShowTrajectory(_ show: Bool) {
        showTrajectoryCheckbox.state = show ? .on : .off
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
    
    // MARK: - Keyboard Input
    
    override var canBecomeKey: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        // Handle Escape to blur text fields
        if event.keyCode == 53 { // Escape key
            makeFirstResponder(contentView)
            return
        }
        
        // Handle digit input for wind force
        guard let characters = event.charactersIgnoringModifiers,
              let char = characters.first,
              char.isNumber else {
            super.keyDown(with: event)
            return
        }
        
        // Append digit and process
        windForceInputBuffer.append(char)
        inputCommitTimer?.invalidate()
        
        // Commit immediately if 2 digits or commit after delay
        if windForceInputBuffer.count >= 2 {
            commitWindForceInput()
        } else {
            inputCommitTimer = Timer.scheduledTimer(
                withTimeInterval: 0.2,
                repeats: false
            ) { [weak self] _ in
                self?.commitWindForceInput()
            }
        }
    }
    
    private func commitWindForceInput() {
        inputCommitTimer?.invalidate()
        inputCommitTimer = nil
        
        guard let value = Int(windForceInputBuffer),
              value >= 1 && value <= 12 else {
            windForceInputBuffer = ""
            return
        }
        
        windForceInputBuffer = ""
        currentWindForce = value
        updateWindForceButtons()
        onWindForceChanged?(Double(value))
    }
    
    // MARK: - Private Methods
    
    private func updateWindForceButtons() {
        let textColor = NSColor.white
        let selectedBgColor = NSColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1.0) // Bright red
        let normalBgColor = NSColor(red: 0.435, green: 0.443, blue: 0.424, alpha: 1.0)
        
        for (index, button) in windForceButtons.enumerated() {
            let level = index + 1
            
            // Remove default bezel so layer styling is the only visual
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 6
            button.layer?.masksToBounds = true
            
            if level == currentWindForce {
                // Selected button styling
                let title = NSAttributedString(
                    string: "\(level)",
                    attributes: [
                        .foregroundColor: textColor,
                        .font: NSFont.boldSystemFont(ofSize: 14)
                    ]
                )
                button.attributedTitle = title
                button.layer?.backgroundColor = selectedBgColor.cgColor
            } else {
                // Normal button styling
                let title = NSAttributedString(
                    string: "\(level)",
                    attributes: [
                        .foregroundColor: textColor,
                        .font: NSFont.systemFont(ofSize: 13, weight: .medium)
                    ]
                )
                button.attributedTitle = title
                button.layer?.backgroundColor = normalBgColor.cgColor
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
                .frame(width: 300, height: 900)
                .previewDisplayName("Control Panel - Default")
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
