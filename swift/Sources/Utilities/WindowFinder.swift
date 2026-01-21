import Cocoa
import CoreGraphics

/// Information about a window found on the system
struct WindowInfo {
    let windowID: CGWindowID
    let title: String
    let frame: CGRect
    
    var origin: CGPoint { frame.origin }
    var size: CGSize { frame.size }
}

/// Utilities for finding and positioning windows on macOS
enum WindowFinder {
    
    /// Find a window by title substring (case-insensitive)
    ///
    /// - Parameter titleSubstring: Substring to search for in window titles
    /// - Returns: WindowInfo if found, nil otherwise
    static func findWindow(withTitleContaining titleSubstring: String) -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }
        
        let searchString = titleSubstring.lowercased()
        
        for windowDict in windowList {
            guard let title = windowDict[kCGWindowName as String] as? String,
                  !title.isEmpty,
                  title.lowercased().contains(searchString) else {
                continue
            }
            
            guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            return WindowInfo(windowID: windowID, title: title, frame: frame)
        }
        
        return nil
    }
    
    /// Get all visible windows
    ///
    /// - Returns: Array of WindowInfo for all on-screen windows
    static func allVisibleWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        
        return windowList.compactMap { windowDict in
            guard let title = windowDict[kCGWindowName as String] as? String,
                  !title.isEmpty,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID else {
                return nil
            }
            
            let frame = CGRect(x: x, y: y, width: width, height: height)
            return WindowInfo(windowID: windowID, title: title, frame: frame)
        }
    }
    
    /// Position a window relative to a target window
    ///
    /// - Parameters:
    ///   - window: Window to position
    ///   - targetTitle: Title substring of target window
    ///   - offset: Offset from target window origin
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
        
        let newOrigin = CGPoint(
            x: targetWindow.origin.x + offset.x,
            y: targetWindow.origin.y + offset.y
        )
        
        window.setFrameOrigin(newOrigin)
        return true
    }
}
