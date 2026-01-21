import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Windows
    
    private var controlWindow: ControlPanelWindow!
    private var overlayWindow: OverlayWindow!
    
    // MARK: - State
    
    private var markerPairs: [MarkerPair] = [.default]
    private var activePairIndex: Int = 0
    private var windSettings: WindSettings = .default
    private var isDragging: Bool = false
    private var shiftPressed: Bool = false
    private var clickThroughIntendedState: Bool = false
    
    // Event monitors for global hotkeys
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // Throttling for drag updates
    private var lastDragUpdate: Date = Date()
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create windows
        controlWindow = ControlPanelWindow()
        overlayWindow = OverlayWindow()
        
        // Setup callbacks
        setupControlWindowCallbacks()
        setupOverlayWindowCallbacks()
        
        // Setup global hotkeys
        setupGlobalHotkeys()
        
        // Position overlay next to control window
        overlayWindow.positionRelativeTo(controlWindow: controlWindow)
        
        // Show windows
        controlWindow.makeKeyAndOrderFront(nil)
        overlayWindow.orderFront(nil)
        
        // Initial update
        updateVisualization()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up event monitors
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupControlWindowCallbacks() {
        controlWindow.onWindForceChanged = { [weak self] force in
            self?.windSettings = WindSettings(force: force, angle: self?.windSettings.angle ?? 90.0)
            self?.updateVisualization()
        }
        
        controlWindow.onWindAngleChanged = { [weak self] angle in
            self?.windSettings = WindSettings(force: self?.windSettings.force ?? 5.0, angle: angle)
            self?.updateVisualization()
        }
        
        controlWindow.onShotAngleChanged = { [weak self] angle in
            guard let self = self else { return }
            if self.activePairIndex < self.markerPairs.count {
                self.markerPairs[self.activePairIndex] = self.markerPairs[self.activePairIndex].withShotAngle(angle)
                self.updateVisualization()
            }
        }
        
        controlWindow.onAddPair = { [weak self] in
            self?.addMarkerPair()
        }
        
        controlWindow.onRemovePair = { [weak self] in
            self?.removeMarkerPair()
        }
        
        controlWindow.onToggleClickThrough = { [weak self] in
            self?.toggleClickThrough()
        }
        
        controlWindow.onPositionOverlay = { [weak self] title, offset in
            self?.positionOverlayToTarget(title: title, offset: offset)
        }
    }
    
    private func setupOverlayWindowCallbacks() {
        let trajectoryView = overlayWindow.getTrajectoryView()
        
        trajectoryView.onMarkerDragged = { [weak self] index, role, position in
            self?.handleMarkerDrag(pairIndex: index, role: role, position: position)
        }
        
        trajectoryView.onPairSelected = { [weak self] index in
            self?.selectPair(at: index)
        }
    }
    
    private func setupGlobalHotkeys() {
        // Local monitor for Cmd+T
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "t" {
                self?.toggleClickThrough()
                return nil  // Consume event
            }
            return event
        }
        
        // Global monitor for Shift key
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        
        // Also monitor local flags changed
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let shiftIsPressed = event.modifierFlags.contains(.shift)
        
        if shiftIsPressed != shiftPressed {
            shiftPressed = shiftIsPressed
            
            if shiftIsPressed && clickThroughIntendedState {
                // Temporarily disable click-through while Shift is held
                overlayWindow.setClickThrough(enabled: false)
                controlWindow.updateClickThroughUI(enabled: true, shiftHeld: true)
            } else if !shiftIsPressed && clickThroughIntendedState {
                // Re-enable click-through when Shift is released
                overlayWindow.setClickThrough(enabled: true)
                controlWindow.updateClickThroughUI(enabled: true, shiftHeld: false)
            }
        }
    }
    
    // MARK: - Marker Pair Management
    
    private func addMarkerPair() {
        guard markerPairs.count < 3 else { return }
        
        // Clone current active pair
        let basePair = markerPairs[activePairIndex]
        markerPairs.append(basePair)
        
        // Make new pair active
        activePairIndex = markerPairs.count - 1
        
        // Update UI
        controlWindow.updatePairButtonStates(pairCount: markerPairs.count)
        controlWindow.setShotAngle(basePair.shotAngle)
        
        updateVisualization()
    }
    
    private func removeMarkerPair() {
        guard markerPairs.count > 1 else { return }
        
        markerPairs.remove(at: activePairIndex)
        
        // Adjust active index
        if activePairIndex >= markerPairs.count {
            activePairIndex = markerPairs.count - 1
        }
        
        // Update UI
        controlWindow.updatePairButtonStates(pairCount: markerPairs.count)
        if activePairIndex < markerPairs.count {
            controlWindow.setShotAngle(markerPairs[activePairIndex].shotAngle)
        }
        
        updateVisualization()
    }
    
    private func selectPair(at index: Int) {
        guard index < markerPairs.count else { return }
        
        activePairIndex = index
        
        // Update control window to show this pair's settings
        let pair = markerPairs[index]
        controlWindow.setShotAngle(pair.shotAngle)
        
        updateVisualization()
    }
    
    // MARK: - Marker Dragging
    
    private func handleMarkerDrag(pairIndex: Int, role: TrajectoryView.MarkerRole, position: CGPoint) {
        guard pairIndex < markerPairs.count else { return }
        
        isDragging = true
        
        // Throttle updates during drag for performance
        let now = Date()
        let shouldUpdate = now.timeIntervalSince(lastDragUpdate) >= 0.016  // ~60 FPS
        
        // Update marker position
        switch role {
        case .player:
            markerPairs[pairIndex] = markerPairs[pairIndex].withPlayerPosition(position)
        case .enemy:
            markerPairs[pairIndex] = markerPairs[pairIndex].withEnemyPosition(position)
        }
        
        if shouldUpdate {
            lastDragUpdate = now
            updateVisualization(useCoarseStep: true)
        }
    }
    
    // MARK: - Click-Through
    
    private func toggleClickThrough() {
        let newState = !clickThroughIntendedState
        clickThroughIntendedState = newState
        
        // Only apply if Shift is not currently held
        if !shiftPressed {
            overlayWindow.setClickThrough(enabled: newState)
        }
        
        controlWindow.updateClickThroughUI(enabled: newState, shiftHeld: shiftPressed)
    }
    
    // MARK: - Window Positioning
    
    private func positionOverlayToTarget(title: String, offset: CGPoint) {
        if WindowFinder.positionWindow(overlayWindow, relativeTo: title, offset: offset) {
            // Success - could show a notification
            print("Positioned overlay to '\(title)'")
        } else {
            // Failed - could show an alert
            print("Could not find window with title '\(title)'")
        }
    }
    
    // MARK: - Visualization Update
    
    private func updateVisualization(useCoarseStep: Bool = false) {
        // Solve for optimal power for each pair
        let powers = TrajectoryCalculator.solveForPowers(
            markerPairs: markerPairs,
            windSettings: windSettings,
            useCoarseStep: useCoarseStep || isDragging
        )
        
        // Update marker pairs with calculated powers
        for (index, power) in powers.enumerated() {
            if index < markerPairs.count {
                markerPairs[index] = markerPairs[index].withShotPower(power)
            }
        }
        
        // Calculate trajectories with current wind
        let trajectories = TrajectoryCalculator.calculateTrajectories(
            markerPairs: markerPairs,
            windSettings: windSettings,
            useCoarseStep: useCoarseStep || isDragging
        )
        
        // Calculate zero-wind trajectories for baseline
        let zeroWindSettings = WindSettings(force: 0, angle: windSettings.angle)
        let zeroWindTrajectories = TrajectoryCalculator.calculateTrajectories(
            markerPairs: markerPairs,
            windSettings: zeroWindSettings,
            useCoarseStep: useCoarseStep || isDragging
        )
        
        // Update trajectory view
        let trajectoryView = overlayWindow.getTrajectoryView()
        trajectoryView.markerPairs = markerPairs
        trajectoryView.activePairIndex = activePairIndex
        trajectoryView.windSettings = windSettings
        trajectoryView.trajectories = trajectories
        trajectoryView.zeroWindTrajectories = zeroWindTrajectories
        
        // Reset dragging flag after update
        if !useCoarseStep {
            isDragging = false
        }
    }
}
