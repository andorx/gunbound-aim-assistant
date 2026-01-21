# Xcode Preview Guide for ControlPanelWindow

## What Was Added

I've updated `ControlPanelWindow.swift` to support **Xcode Previews**, allowing you to see and interact with the UI directly in Xcode without running the full application.

## Changes Made

### 1. Added SwiftUI Import
```swift
import SwiftUI
```

### 2. Added Preview Support Section
At the end of the file, added:
- `ControlPanelWindowPreview`: NSViewRepresentable wrapper for the AppKit window
- `ControlPanelWindow_Previews`: PreviewProvider with multiple preview configurations

### 3. Preview Features
- **Default State Preview**: Shows the control panel in light mode
- **Dark Mode Preview**: Shows the control panel in dark mode
- **Pre-configured State**: Window is initialized with realistic default values
  - Wind Force: 5
  - Wind Angle: 90°
  - Shot Angle: 45°
  - Pair Count: 2
  - Click-Through: Disabled

## How to Use Xcode Previews

### Step 1: Open the File in Xcode
1. Open `GunboundAimAssistant.xcworkspace` in Xcode
2. Navigate to `Sources/Windows/ControlPanelWindow.swift`

### Step 2: Enable Canvas
- **Option 1**: Press `⌥⌘↩` (Option + Command + Return)
- **Option 2**: Click **Editor → Canvas** in the menu bar
- **Option 3**: Click the canvas icon in the top-right toolbar

### Step 3: View the Preview
The canvas will appear on the right side showing:
- **Control Panel - Default**: Light mode appearance
- **Control Panel - Dark Mode**: Dark mode appearance

### Step 4: Interact with Preview
- Click the **▶️ Play** button on the preview to make it interactive
- Test buttons, sliders, and knobs in real-time
- Switch between light and dark mode previews

## Preview Benefits

✅ **Instant Feedback**: See UI changes immediately without building  
✅ **Multiple States**: View different configurations side-by-side  
✅ **Dark Mode Testing**: Test appearance in both light and dark modes  
✅ **Faster Iteration**: No need to run the full app for UI tweaks  
✅ **Interactive**: Click and interact with controls in preview mode  

## Customizing Previews

You can modify the preview configuration in the `makeNSView` method:

```swift
func makeNSView(context: Context) -> NSView {
    let window = ControlPanelWindow()
    
    // Customize initial state here
    window.setWindForce(8.0)        // Change wind force
    window.setWindAngle(180.0)      // Change wind angle
    window.setShotAngle(60.0)       // Change shot angle
    window.updatePairButtonStates(pairCount: 3)  // Change pair count
    window.updateClickThroughUI(enabled: true, shiftHeld: false)  // Enable click-through
    
    return window.contentView ?? NSView()
}
```

## Adding More Preview Variants

You can add additional preview configurations:

```swift
static var previews: some View {
    Group {
        // Default state
        ControlPanelWindowPreview()
            .frame(width: 300, height: 780)
            .previewDisplayName("Control Panel - Default")
        
        // Dark mode
        ControlPanelWindowPreview()
            .frame(width: 300, height: 780)
            .preferredColorScheme(.dark)
            .previewDisplayName("Control Panel - Dark Mode")
        
        // Add your custom variant here
        ControlPanelWindowPreview()
            .frame(width: 300, height: 780)
            .previewDisplayName("Control Panel - Custom State")
    }
}
```

## Troubleshooting

### Preview Not Showing
- Make sure you're in a Swift file with preview code
- Try pressing `⌥⌘P` to refresh the preview
- Check that the canvas is enabled (Editor → Canvas)

### Preview Build Failed
- Check the build log in the canvas area
- Ensure all dependencies are available
- Try cleaning the build folder (⌘⇧K)

### Preview is Slow
- Previews compile incrementally, first load may be slow
- Subsequent updates should be faster
- Consider reducing the number of preview variants

## Debug-Only Code

The preview code is wrapped in `#if DEBUG` to ensure it's only included in debug builds:

```swift
#if DEBUG
// Preview code here
#endif
```

This means:
- ✅ Available in Debug builds
- ✅ Available in Xcode Previews
- ❌ Not included in Release builds
- ❌ No performance impact on production

## Next Steps

Consider adding previews to other UI components:
- `CircularKnob.swift`
- `TrajectoryView.swift`
- `OverlayWindow.swift`

The same pattern can be applied to any AppKit view or window!

---

**Enjoy faster UI development with Xcode Previews!** 🎨
