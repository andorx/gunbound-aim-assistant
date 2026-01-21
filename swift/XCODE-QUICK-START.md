# Xcode Workspace Quick Start Guide

## Opening the Project

```bash
cd swift
open GunboundAimAssistant.xcworkspace
```

**⚠️ Important**: Always open the `.xcworkspace` file, NOT the `.xcodeproj`

## Building

### In Xcode
- **Build**: ⌘B (Command + B)
- **Run**: ⌘R (Command + R)
- **Clean**: ⌘⇧K (Command + Shift + K)

### Command Line
```bash
# Debug build
xcodebuild -workspace GunboundAimAssistant.xcworkspace \
           -scheme GunboundAimAssistant \
           -configuration Debug \
           build

# Release build
xcodebuild -workspace GunboundAimAssistant.xcworkspace \
           -scheme GunboundAimAssistant \
           -configuration Release \
           build
```

## Project Structure

```
GunboundAimAssistant.xcworkspace/  ← Open this
├── GunboundAimAssistant.xcodeproj/
├── Sources/
│   ├── App/
│   ├── Models/
│   ├── Physics/
│   ├── UI/
│   ├── Utilities/
│   └── Windows/
├── Assets.xcassets/
├── Info.plist
└── GunboundAimAssistant.entitlements
```

## Key Files

- **Workspace**: `GunboundAimAssistant.xcworkspace` - Open this in Xcode
- **Project**: `GunboundAimAssistant.xcodeproj` - Contains build settings
- **Info.plist**: App metadata and configuration
- **Entitlements**: Security permissions
- **Assets**: App icons and resources

## Build Configurations

- **Debug**: Development builds with debugging enabled
- **Release**: Optimized builds for distribution

## Next Steps

1. **Configure Code Signing** (if distributing):
   - Open workspace in Xcode
   - Select project → Target → Signing & Capabilities
   - Choose your development team

2. **Add App Icon**:
   - Open Assets.xcassets in Xcode
   - Select AppIcon
   - Drag and drop icon images

3. **Customize Settings**:
   - Project settings: Select project in navigator
   - Build settings: Build Settings tab
   - Capabilities: Signing & Capabilities tab

## Troubleshooting

- **Workspace won't open**: Make sure Xcode is installed
- **Build fails**: Check build log in Xcode (⌘9 to show)
- **Code signing issues**: Disable automatic signing or select team

For detailed information, see: `.tmp/sessions/2026-01-21-xcode-workspace-setup/COMPLETION-SUMMARY.md`
