date: 2026-01-22
topic: "Quick Window Focus with Shift Key"
status: validated

# Problem Statement

When click-through is **disabled** (the intended state is false), users must click twice on the OverlayWindow: first to focus it, then to interact with markers. This breaks the workflow for quick marker adjustments.

**Desired behavior:** Hold Shift → OverlayWindow immediately becomes focused/active →可以直接拖动 markers.

# Constraints

- Must not break existing click-through toggle behavior
- Must work when the app is not the active application
- Must be compatible with the existing temporary click-through disable (when click-through is enabled)

# Approach

**Chosen approach:** Extend the existing Shift key behavior in `handleFlagsChanged` to manage two modes:

**Mode 1 - Click-through intended as ENABLED (existing):**
- Shift held → temporarily disable click-through
- Shift released → restore click-through

**Mode 2 - Click-through intended as DISABLED (new):**
- Shift held → make OverlayWindow key and activate app
- Shift released → no action (window stays focused)

**Why this approach:**
- Builds on existing mental model (Shift = temporary interaction mode)
- Minimal code changes
- Consistent with UI label "Hold Shift: Quick Adjust Markers"
- No new state management needed

# Architecture

The Shift key event flow through AppDelegate:

```
User presses Shift
  ↓
NSEvent flagsChanged event (global + local monitors)
  ↓
handleFlagsChanged(event) in AppDelegate
  ↓
Check shiftIsPressed state change
  ↓
If Shift pressed AND clickThroughIntendedState == false:
  → overlayWindow.makeKeyAndOrderFront(nil)
  → NSApp.activate(ignoringOtherApps: true)
  → OverlayWindow becomes key window immediately
```

# Components

## AppDelegate - handleFlagsChanged

**Current responsibilities:**
- Detect Shift key state changes
- Temporarily toggle click-through when click-through is enabled

**New responsibility:**
- Focus OverlayWindow when click-through is disabled and Shift is pressed

**Implementation:**
- Add branch in `handleFlagsChanged` to check `!clickThroughIntendedState`
- Call window focusing methods when Shift is pressed

# Data Flow

### Shift Pressed Flow (Click-through Disabled)

```
1. User holds Shift key
   ↓
2. handleFlagsChanged detects Shift pressed
   ↓
3. Check: clickThroughIntendedState == false?
   ↓ Yes
4. overlayWindow.makeKeyAndOrderFront(nil)
   ↓
5. NSApp.activate(ignoringOtherApps: true)
   ↓
6. OverlayWindow becomes key window
   ↓
7. User can immediately drag markers (no extra click)
```

### Shift Released Flow

```
1. User releases Shift key
   ↓
2. handleFlagsChanged detects Shift released
   ↓
3. Check: Was focusing applied?
   ↓ Yes
4. No action needed - window remains key
   (User can continue interacting)
```

# Error Handling

**Potential issues:**
- **Window doesn't exist**: Handle nil safely with optional binding
- **Focusing fails**: Non-critical, user can still click manually
- **Race condition**: macOS window manager handles concurrent focus events gracefully

**Strategy:**
- No special error handling needed - these are non-critical UI operations
- Worst case: Shift press has no effect, user clicks manually as before

# Testing Strategy

**Manual test scenarios:**

1. **App not focused, click-through disabled**
   - Hold Shift → OverlayWindow becomes key window immediately
   - Can drag markers without clicking twice

2. **App focused on control window, click-through disabled**
   - Hold Shift → Focus shifts to OverlayWindow
   - Can drag markers immediately

3. **Click-through enabled (existing behavior)**
   - Hold Shift → Click-through temporarily disabled
   - Can interact with markers
   - Release Shift → Click-through restored

4. **Release Shift in both states**
   - Appropriate state should be maintained

**Edge cases to verify:**
- Other application has focus → Should bring app to front
- Multiple monitors → Should work correctly
- OverlayWindow minimized → Should unminimize and focus

# Open Questions

None. This is a straightforward enhancement to existing behavior with clear requirements and minimal risk.
