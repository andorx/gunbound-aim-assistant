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
    
    /// Make a color darker by a given factor
    ///
    /// - Parameters:
    ///   - color: The color to darken
    ///   - factor: Amount to darken (0.0 to 1.0, where 1.0 is fully black)
    /// - Returns: Darker color
    static func darker(_ color: NSColor, by factor: CGFloat) -> NSColor {
        let factor = max(0.0, min(1.0, factor))
        
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return color
        }
        
        return NSColor(
            red: max(0, rgb.redComponent * (1 - factor)),
            green: max(0, rgb.greenComponent * (1 - factor)),
            blue: max(0, rgb.blueComponent * (1 - factor)),
            alpha: rgb.alphaComponent
        )
    }
    
    /// Make a color lighter by a given factor
    ///
    /// - Parameters:
    ///   - color: The color to lighten
    ///   - factor: Amount to lighten (0.0 to 1.0, where 1.0 is fully white)
    /// - Returns: Lighter color
    static func lighter(_ color: NSColor, by factor: CGFloat) -> NSColor {
        let factor = max(0.0, min(1.0, factor))
        
        guard let rgb = color.usingColorSpace(.deviceRGB) else {
            return color
        }
        
        return NSColor(
            red: min(1, rgb.redComponent + (1 - rgb.redComponent) * factor),
            green: min(1, rgb.greenComponent + (1 - rgb.greenComponent) * factor),
            blue: min(1, rgb.blueComponent + (1 - rgb.blueComponent) * factor),
            alpha: rgb.alphaComponent
        )
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

        static let pair1Color = ColorUtilities.color(fromHex: "#E11946")!
        static let pair2Color = ColorUtilities.color(fromHex: "#8931EF")!
        static let pair3Color = ColorUtilities.color(fromHex: "#0257EA")!
        
        static let pair1 = MarkerColors(
            player: pair1Color,
            enemy: ColorUtilities.darker(pair1Color, by: 0.1),
            zeroWind: pair1Color,
            trajectoryStart: pair1Color,
            trajectoryEnd: pair1Color
        )
        
        static let pair2 = MarkerColors(
            player: pair2Color,
            enemy: ColorUtilities.darker(pair2Color, by: 0.1),
            zeroWind: pair2Color,
            trajectoryStart: pair2Color,
            trajectoryEnd: pair2Color
        )
        
        static let pair3 = MarkerColors(
            player: pair3Color,
            enemy: ColorUtilities.darker(pair3Color, by: 0.1),
            zeroWind: pair3Color,
            trajectoryStart: pair3Color,
            trajectoryEnd: pair3Color
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
