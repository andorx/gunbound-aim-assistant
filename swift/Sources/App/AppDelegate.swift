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
    private var modifierKeyPressed: Bool = false
    private var clickThroughIntendedState: Bool = false
    private var colorPaletteOffset: Int = 0

    // Event monitors for global hotkeys
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    // Throttling for drag updates
    private var lastDragUpdate: Date = Date()

    // Flag to prevent recursive window closing
    private var isClosingWindows: Bool = false

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup main menu (required for Cmd+Q to work)
        setupMainMenu()

        // Check for Screen Recording permission (required for window finding)
        checkScreenRecordingPermission()

        // Create windows
        controlWindow = ControlPanelWindow()
        overlayWindow = OverlayWindow()

        // Setup callbacks
        setupControlWindowCallbacks()
        setupOverlayWindowCallbacks()

        // Setup window close observers (close both windows together)
        setupWindowCloseObservers()

        // Setup global hotkeys
        setupGlobalHotkeys()

        // Position overlay next to control window
        overlayWindow.positionRelativeTo(controlWindow: controlWindow)

        // Show windows
        controlWindow.makeKeyAndOrderFront(nil)
        overlayWindow.orderFront(nil)

        // Initial update
        updateVisualization()

        // Debug: print all visible windows (remove in production)
        #if DEBUG
        WindowFinder.debugPrintAllWindows()
        #endif
    }

    private func checkScreenRecordingPermission() {
        if !WindowFinder.hasScreenRecordingPermission() {
            print("⚠️ Screen Recording permission not granted.")
            print("   Window finding features may not work correctly.")
            print("   Go to: System Settings > Privacy & Security > Screen Recording")
            print("   and enable this app.")

            // Trigger permission request dialog
            WindowFinder.requestScreenRecordingPermission()
        } else {
            print("✅ Screen Recording permission granted.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up event monitors
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Setup

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu (shows app name in menu bar)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        // About item
        let aboutItem = NSMenuItem(
            title: "About Gunbound Aim Assistant",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)

        appMenu.addItem(NSMenuItem.separator())

        // Hide item (Cmd+H)
        let hideItem = NSMenuItem(
            title: "Hide Gunbound Aim Assistant",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        // Hide Others item (Cmd+Option+H)
        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        // Show All item
        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)

        appMenu.addItem(NSMenuItem.separator())

        // Quit item (Cmd+Q)
        let quitItem = NSMenuItem(
            title: "Quit Gunbound Aim Assistant",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupWindowCloseObservers() {
        // Observe when either window is about to close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: controlWindow
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: overlayWindow
        )
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // Prevent recursive closing
        guard !isClosingWindows else { return }
        isClosingWindows = true

        // Close both windows
        controlWindow.close()
        overlayWindow.close()

        // Terminate the application
        NSApp.terminate(nil)
    }

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

        controlWindow.onToggleTrajectory = { [weak self] showTrajectory in
            self?.overlayWindow.getTrajectoryView().showTrajectory = showTrajectory
        }

        controlWindow.onRotateColors = { [weak self] in
            self?.rotateColorPalette()
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

        // Global monitor for modifier key
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
        let modifierKeyIsPressed = event.modifierFlags.contains(.control)

        if modifierKeyIsPressed != modifierKeyPressed {
            modifierKeyPressed = modifierKeyIsPressed

            if modifierKeyIsPressed && clickThroughIntendedState {
                // Temporarily disable click-through while modifier key is held
                overlayWindow.setClickThrough(enabled: false)
                controlWindow.updateClickThroughUI(enabled: true, modifierKeyHeld: true)

                // Quick focus: When click-through is disabled, modifier key focuses OverlayWindow
                self.overlayWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else if !modifierKeyIsPressed && clickThroughIntendedState {
                // Re-enable click-through when modifier key is released
                overlayWindow.setClickThrough(enabled: true)
                controlWindow.updateClickThroughUI(enabled: true, modifierKeyHeld: false)
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

    // MARK: - Color Palette

    private func rotateColorPalette() {
        colorPaletteOffset = (colorPaletteOffset + 1) % 3
        
        // Update trajectory view
        let trajectoryView = overlayWindow.getTrajectoryView()
        trajectoryView.colorPaletteOffset = colorPaletteOffset
    }

    // MARK: - Click-Through

    private func toggleClickThrough() {
        let newState = !clickThroughIntendedState
        clickThroughIntendedState = newState

        // Only apply if modifier key is not currently held
        if !modifierKeyPressed {
            overlayWindow.setClickThrough(enabled: newState)
        }

        controlWindow.updateClickThroughUI(enabled: newState, modifierKeyHeld: modifierKeyPressed)
    }

    // MARK: - Window Positioning

    private func positionOverlayToTarget(title: String, offset: CGPoint) {
        if WindowFinder.positionWindow(overlayWindow, relativeTo: title, offset: offset) {
            // Success - position control panel to the left of overlay
            let overlayFrame = overlayWindow.frame
            let controlWidth = controlWindow.frame.width
            let controlPanelOrigin = CGPoint(
                x: overlayFrame.origin.x - controlWidth,
                y: overlayFrame.origin.y + overlayFrame.height - controlWindow.frame.height + offset.y
            )
            controlWindow.setFrameOrigin(controlPanelOrigin)

            print("✅ Positioned overlay to '\(title)' with control panel adjacent")
        } else {
            // Failed - provide diagnostic info
            print("❌ Could not find window with title '\(title)'")

            if !WindowFinder.hasScreenRecordingPermission() {
                print("   💡 Hint: Screen Recording permission may be missing.")
                print("   Go to: System Settings > Privacy & Security > Screen Recording")
            } else {
                // List available windows to help user find the correct title
                print("   Available windows:")
                let windows = WindowFinder.allVisibleWindows(includeEmpty: true)
                for window in windows.prefix(10) {
                    let titleStr = window.title.isEmpty ? "(no title)" : window.title
                    print("   - [\(window.ownerName)] \(titleStr)")
                }
                if windows.count > 10 {
                    print("   ... and \(windows.count - 10) more")
                }
            }
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
