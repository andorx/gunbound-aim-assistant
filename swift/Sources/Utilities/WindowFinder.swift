import Cocoa
import CoreGraphics

/// Information about a window found on the system
struct WindowInfo {
    let windowID: CGWindowID
    let ownerName: String  // Application name
    let title: String      // Window title (may be empty)
    let frame: CGRect
    let ownerPID: pid_t

    var origin: CGPoint { frame.origin }
    var size: CGSize { frame.size }

    /// Display name: prefer window title, fallback to owner name
    var displayName: String {
        title.isEmpty ? ownerName : title
    }
}

/// Utilities for finding and positioning windows on macOS
///
/// **IMPORTANT**: This utility requires **Screen Recording** permission to access
/// window titles from other applications. Go to:
/// System Settings > Privacy & Security > Screen Recording > Enable for this app
///
/// Note: Accessibility permission is NOT sufficient for reading window information.
enum WindowFinder {

    // MARK: - Permission Check

    /// Check if the app has Screen Recording permission
    /// - Returns: True if permission is granted, false otherwise
    static func hasScreenRecordingPermission() -> Bool {
        // Try to get window list - if we can read window names from other apps, we have permission
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        // Check if we can read titles from windows owned by other processes
        let myPID = ProcessInfo.processInfo.processIdentifier

        for windowDict in windowList {
            guard let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != myPID else {
                continue
            }

            // If we can read a non-empty title from another process, we have permission
            if let title = windowDict[kCGWindowName as String] as? String, !title.isEmpty {
                return true
            }
        }

        // If we only see our own windows or no titles, we likely don't have permission
        // But also could be that no other windows have titles, so check if we see other apps at all
        let hasOtherApps = windowList.contains { dict in
            guard let pid = dict[kCGWindowOwnerPID as String] as? pid_t else { return false }
            return pid != myPID
        }

        // If we see other apps but none have titles, permission is likely missing
        return !hasOtherApps
    }

    /// Request Screen Recording permission by triggering the system prompt
    /// - Note: This will open System Settings if permission is not granted
    static func requestScreenRecordingPermission() {
        // Attempt to capture a tiny portion of the screen - this triggers the permission dialog
        let displayID = CGMainDisplayID()
        _ = CGDisplayCreateImage(displayID, rect: CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    // MARK: - Window Finding

    /// Find a window by title or owner name substring (case-insensitive)
    ///
    /// - Parameters:
    ///   - titleSubstring: Substring to search for in window titles or owner names
    ///   - preferTitle: If true, prioritize title matches over owner name matches
    /// - Returns: WindowInfo if found, nil otherwise
    static func findWindow(withTitleContaining titleSubstring: String, preferTitle: Bool = true) -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let searchString = titleSubstring.lowercased()
        var ownerMatch: WindowInfo? = nil

        for windowDict in windowList {
            guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            // Skip tiny windows (likely utility windows)
            guard width > 50 && height > 50 else { continue }

            let title = windowDict[kCGWindowName as String] as? String ?? ""
            let ownerName = windowDict[kCGWindowOwnerName as String] as? String ?? ""
            let frame = CGRect(x: x, y: y, width: width, height: height)
            let info = WindowInfo(windowID: windowID, ownerName: ownerName, title: title, frame: frame, ownerPID: ownerPID)

            // Check title match (preferred)
            if !title.isEmpty && title.lowercased().contains(searchString) {
                return info
            }

            // Check owner name match (fallback)
            if ownerMatch == nil && !ownerName.isEmpty && ownerName.lowercased().contains(searchString) {
                ownerMatch = info
            }
        }

        // Return owner match if no title match found
        return ownerMatch
    }

    /// Get all visible windows
    ///
    /// - Parameters:
    ///   - includeEmpty: If true, include windows with empty titles
    ///   - minSize: Minimum window size to include (filters out utility windows)
    /// - Returns: Array of WindowInfo for all on-screen windows
    static func allVisibleWindows(includeEmpty: Bool = false, minSize: CGFloat = 50) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { windowDict in
            guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t else {
                return nil
            }

            // Filter by minimum size
            guard width >= minSize && height >= minSize else { return nil }

            let title = windowDict[kCGWindowName as String] as? String ?? ""
            let ownerName = windowDict[kCGWindowOwnerName as String] as? String ?? ""

            // Filter empty titles if requested
            if !includeEmpty && title.isEmpty && ownerName.isEmpty {
                return nil
            }

            let frame = CGRect(x: x, y: y, width: width, height: height)
            return WindowInfo(windowID: windowID, ownerName: ownerName, title: title, frame: frame, ownerPID: ownerPID)
        }
    }

    /// Position a window relative to a target window
    ///
    /// - Parameters:
    ///   - window: Window to position
    ///   - targetTitle: Title substring of target window
    ///   - offset: Offset from target window origin (in screen coordinates, positive Y = down)
    /// - Returns: True if successful, false if target not found
    @discardableResult
    static func positionWindow(
        _ window: NSWindow,
        relativeTo targetTitle: String,
        offset: CGPoint = .zero
    ) -> Bool {
        guard let targetWindow = findWindow(withTitleContaining: targetTitle) else {
            return false
        }

        // Convert from CG coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
        let cocoaOrigin = convertToCocoaCoordinates(
            cgPoint: targetWindow.origin,
            windowHeight: window.frame.height
        )

        // Apply offset (note: offset.y positive means DOWN in screen coords, which is negative in Cocoa)
        let newOrigin = CGPoint(
            x: cocoaOrigin.x + offset.x,
            y: cocoaOrigin.y - offset.y
        )

        print("Target CG origin: \(targetWindow.origin), Cocoa origin: \(cocoaOrigin), Final: \(newOrigin)")

        window.setFrameOrigin(newOrigin)
        return true
    }

    /// Convert a point from CG screen coordinates (top-left origin) to Cocoa coordinates (bottom-left origin)
    ///
    /// - Parameters:
    ///   - cgPoint: Point in CG coordinates (origin at top-left of primary display)
    ///   - windowHeight: Height of the window being positioned
    /// - Returns: Point in Cocoa coordinates (origin at bottom-left of primary display)
    static func convertToCocoaCoordinates(cgPoint: CGPoint, windowHeight: CGFloat) -> CGPoint {
        // Get the height of the primary screen (main display)
        guard let mainScreen = NSScreen.screens.first else {
            return cgPoint
        }

        let screenHeight = mainScreen.frame.height

        // CG: Y increases downward from top
        // Cocoa: Y increases upward from bottom
        // Cocoa Y = screenHeight - CG Y - windowHeight
        let cocoaY = screenHeight - cgPoint.y - windowHeight

        return CGPoint(x: cgPoint.x, y: cocoaY)
    }

    /// Convert a CGRect from CG screen coordinates to Cocoa coordinates
    static func convertToCocoaCoordinates(cgRect: CGRect) -> CGRect {
        let origin = convertToCocoaCoordinates(cgPoint: cgRect.origin, windowHeight: cgRect.height)
        return CGRect(origin: origin, size: cgRect.size)
    }

    // MARK: - Debugging

    /// Print all visible windows for debugging purposes
    /// Useful for understanding what windows are accessible and verifying Screen Recording permission
    static func debugPrintAllWindows() {
        print("=== WindowFinder Debug ===")
        print("Screen Recording Permission: \(hasScreenRecordingPermission() ? "✅ Granted" : "❌ Not Granted")")
        print("")

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            print("❌ Failed to get window list")
            return
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        print("My PID: \(myPID)")
        print("Total windows found: \(windowList.count)")
        print("")

        for (index, windowDict) in windowList.enumerated() {
            let title = windowDict[kCGWindowName as String] as? String ?? "(nil)"
            let ownerName = windowDict[kCGWindowOwnerName as String] as? String ?? "(nil)"
            let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t ?? -1
            let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID ?? 0
            let layer = windowDict[kCGWindowLayer as String] as? Int ?? -1

            var posStr = "unknown"
            var sizeStr = "unknown"
            if let bounds = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
               let x = bounds["X"], let y = bounds["Y"],
               let w = bounds["Width"], let h = bounds["Height"] {
                posStr = "(\(Int(x)), \(Int(y)))"
                sizeStr = "\(Int(w))x\(Int(h))"
            }

            let isMine = ownerPID == myPID ? " (mine)" : ""
            let titleDisplay = title.isEmpty ? "(empty)" : "'\(title)'"

            print("[\(index)] WinID:\(windowID) PID:\(ownerPID)\(isMine) Layer:\(layer)")
            print("    Owner: '\(ownerName)'")
            print("    Title: \(titleDisplay)")
            print("    Position: \(posStr)  Size: \(sizeStr)")
            print("")
        }

        print("=== End Debug ===")
    }
}
