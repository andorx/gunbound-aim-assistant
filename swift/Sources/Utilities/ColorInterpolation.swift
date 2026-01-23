import AppKit

/// Pure functions for color manipulation and interpolation
enum ColorUtilities {
    
    /// Interpolate between two colors
    ///
    /// - Parameters:
    ///   - color1: Starting color
    ///   - color2: Ending color
    ///   - t: Interpolation factor (0.0 to 1.0)
    /// - Returns: Interpolated color
    static func interpolate(from color1: NSColor, to color2: NSColor, t: Double) -> NSColor {
        let t = max(0.0, min(1.0, t))  // Clamp to [0, 1]
        
        // Convert to RGB color space
        guard let rgb1 = color1.usingColorSpace(.deviceRGB),
              let rgb2 = color2.usingColorSpace(.deviceRGB) else {
            return color1
        }
        
        // Interpolate components
        let r = rgb1.redComponent + (rgb2.redComponent - rgb1.redComponent) * t
        let g = rgb1.greenComponent + (rgb2.greenComponent - rgb1.greenComponent) * t
        let b = rgb1.blueComponent + (rgb2.blueComponent - rgb1.blueComponent) * t
        let a = rgb1.alphaComponent + (rgb2.alphaComponent - rgb1.alphaComponent) * t
        
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }
    
    /// Create color from hex string
    ///
    /// - Parameter hex: Hex color string (e.g., "#FF0000" or "FF0000")
    /// - Returns: NSColor or nil if invalid
    static func color(fromHex hex: String) -> NSColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        guard hexSanitized.count == 6 else { return nil }
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    /// Convert NSColor to hex string
    ///
    /// - Parameter color: Color to convert
    /// - Returns: Hex string (e.g., "#FF0000")
    static func hexString(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return "#000000"
        }
        
        let r = Int(rgb.redComponent * 255.0)
        let g = Int(rgb.greenComponent * 255.0)
        let b = Int(rgb.blueComponent * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Predefined Color Palettes

extension ColorUtilities {
    
    /// Color palette for marker pairs
    struct MarkerColors {
        let player: NSColor
        let enemy: NSColor
        let zeroWind: NSColor
        let trajectoryStart: NSColor
        let trajectoryEnd: NSColor
        
        static let pair1 = MarkerColors(
            player: ColorUtilities.color(fromHex: "#fc8181")!,
            enemy: ColorUtilities.color(fromHex: "#FC5981")!,
            zeroWind: ColorUtilities.color(fromHex: "#fc8181")!,
            trajectoryStart: ColorUtilities.color(fromHex: "#fc8181")!,
            trajectoryEnd: ColorUtilities.color(fromHex: "#fc8181")!
        )
        
        static let pair2 = MarkerColors(
            player: ColorUtilities.color(fromHex: "#F08402")!,
            enemy: ColorUtilities.color(fromHex: "#F06A02")!,
            zeroWind: ColorUtilities.color(fromHex: "#F08402")!,
            trajectoryStart: ColorUtilities.color(fromHex: "#F08402")!,
            trajectoryEnd: ColorUtilities.color(fromHex: "#F08402")!
        )
        
        static let pair3 = MarkerColors(
            player: ColorUtilities.color(fromHex: "#0C5EEA")!,
            enemy: ColorUtilities.color(fromHex: "#0C45EA")!,
            zeroWind: ColorUtilities.color(fromHex: "#0C5EEA")!,
            trajectoryStart: ColorUtilities.color(fromHex: "#0C5EEA")!,
            trajectoryEnd: ColorUtilities.color(fromHex: "#0C5EEA")!
        )
        
        static func forPair(at index: Int) -> MarkerColors {
            switch index % 3 {
            case 0: return pair1
            case 1: return pair2
            default: return pair3
            }
        }
    }
}
