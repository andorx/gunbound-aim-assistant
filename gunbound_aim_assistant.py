#!/usr/bin/env python3
"""
Gunbound Mobile Aim Assistant
An overlay tool to help with aiming calculations and trajectory visualization
"""

import tkinter as tk
from tkinter import ttk
import math
import sys
import threading

# Global hotkey support
try:
    from pynput import keyboard
    PYNPUT_AVAILABLE = True
except ImportError:
    PYNPUT_AVAILABLE = False
    print("Warning: pynput not installed. Global hotkey (Shift) will not work.")
    print("Install with: pip install pynput")

# macOS-specific imports for window detection
if sys.platform == 'darwin':
    try:
        from Quartz import CGWindowListCopyWindowInfo, kCGWindowListOptionOnScreenOnly, kCGNullWindowID
        from Quartz.CoreGraphics import CGRect, CGRectNull
        from Cocoa import NSWorkspace
    except ImportError:
        print("Warning: pyobjc-framework-Quartz not installed. Window detection will not work.")
        print("Install with: pip install pyobjc-framework-Quartz")


class CircularKnob(tk.Canvas):
    """A circular knob widget for selecting angles 0-360 degrees"""

    def __init__(self, parent, size=120, initial_angle=90, command=None, **kwargs):
        super().__init__(parent, width=size, height=size, **kwargs)
        self.size = size
        self.center_x = size // 2
        self.center_y = size // 2
        self.radius = (size // 2) - 10
        self.knob_radius = 8
        self.angle = initial_angle
        self.command = command

        # Bind mouse events
        self.bind("<Button-1>", self.on_click)
        self.bind("<B1-Motion>", self.on_drag)

        # Initial draw
        self.draw_knob()

    def draw_knob(self):
        """Draw the circular knob with current angle"""
        self.delete("all")

        # Draw outer circle (track)
        self.create_oval(
            self.center_x - self.radius, self.center_y - self.radius,
            self.center_x + self.radius, self.center_y + self.radius,
            fill="#2d3748", outline="#4a5568", width=2
        )

        # Draw direction indicators (N, E, S, W)
        directions = [
            (0, -self.radius + 15, "12"),
            (self.radius - 15, 0, "3"),
            (0, self.radius - 15, "6"),
            (-self.radius + 15, 0, "9")
        ]
        for dx, dy, label in directions:
            self.create_text(
                self.center_x + dx, self.center_y + dy,
                text=label, fill="#718096", font=("Arial", 8, "bold")
            )

        # Draw tick marks every 30 degrees (hours)
        for tick_angle in range(0, 360, 30):
            angle_rad = math.radians(tick_angle)
            # Make hour marks slightly longer
            x1 = self.center_x + (self.radius - 5) * math.cos(angle_rad)
            y1 = self.center_y - (self.radius - 5) * math.sin(angle_rad)
            x2 = self.center_x + (self.radius - 10) * math.cos(angle_rad)
            y2 = self.center_y - (self.radius - 10) * math.sin(angle_rad)
            self.create_line(x1, y1, x2, y2, fill="#718096", width=2)

        # Draw smaller ticks for half-hours (15 degrees offset)
        for tick_angle in range(15, 360, 30):
            angle_rad = math.radians(tick_angle)
            x1 = self.center_x + (self.radius - 5) * math.cos(angle_rad)
            y1 = self.center_y - (self.radius - 5) * math.sin(angle_rad)
            x2 = self.center_x + (self.radius - 8) * math.cos(angle_rad)
            y2 = self.center_y - (self.radius - 8) * math.sin(angle_rad)
            self.create_line(x1, y1, x2, y2, fill="#4a5568", width=1)

        # Calculate knob position based on angle
        angle_rad = math.radians(self.angle)
        knob_x = self.center_x + (self.radius - 20) * math.cos(angle_rad)
        knob_y = self.center_y - (self.radius - 20) * math.sin(angle_rad)

        # Draw knob circle
        self.create_oval(
            knob_x - self.knob_radius, knob_y - self.knob_radius,
            knob_x + self.knob_radius, knob_y + self.knob_radius,
            fill="#63b3ed", outline="#3182ce", width=2
        )

        # Draw clock time text in center
        clock_text = self.format_clock_time(self.angle)
        self.create_text(
            self.center_x, self.center_y,
            text=clock_text, fill="#e2e8f0",
            font=("Arial", 10, "bold")
        )

    def on_click(self, event):
        """Handle mouse click to update angle"""
        self.update_angle_from_position(event.x, event.y)

    def on_drag(self, event):
        """Handle mouse drag to update angle"""
        self.update_angle_from_position(event.x, event.y)

    def update_angle_from_position(self, x, y):
        """Calculate and update angle from mouse position"""
        dx = x - self.center_x
        dy = self.center_y - y  # Invert Y for correct angle calculation

        # Calculate angle in degrees
        angle = math.degrees(math.atan2(dy, dx))
        if angle < 0:
            angle += 360

        # Snap to nearest 15 degrees (30 minutes on clock)
        step = 15
        snapped_angle = round(angle / step) * step
        snapped_angle = snapped_angle % 360

        self.angle = snapped_angle
        self.draw_knob()

        # Call command if provided
        if self.command:
            self.command(self.angle)

    def format_clock_time(self, angle):
        """Convert angle to clock string (e.g. 1, 1:30, 12)"""
        # 90 degrees is 12 o'clock
        # Moving clockwise (decreasing angle in standard trig)

        # Calculate deviation from 12 o'clock (90 degrees)
        # Clockwise distance in degrees
        deg_from_12 = (90 - angle) % 360

        # 30 degrees = 1 hour
        hours_float = deg_from_12 / 30
        hour = int(hours_float)
        minute_part = hours_float - hour

        # Handle 0 hour as 12
        if hour == 0:
            hour = 12

        # Check if it's a half hour (approx 0.5)
        if abs(minute_part - 0.5) < 0.1:
            return f"{hour}:30"
        else:
            return f"{hour}"

    def get_angle(self):
        """Get current angle value"""
        return self.angle

    def set_angle(self, angle):
        """Set angle programmatically"""
        self.angle = angle % 360
        self.draw_knob()


class GunboundAimAssistant:
    def __init__(self, root):
        self.root = root
        self.root.title("Aim Controls")
        self.root.geometry("300x720")  # Taller to accommodate window positioning controls
        self.root.resizable(False, False)
        self.root.attributes("-topmost", True)

        # Handle window closing
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

        # Create the separate overlay window
        self.overlay_window = tk.Toplevel(self.root)
        self.overlay_window.title("Gunbound Overlay")
        self.overlay_window.geometry("1050x850")
        self.overlay_window.resizable(False, False)

        # Overlay specific settings
        self.overlay_window.attributes("-alpha", 0.9)
        self.overlay_window.attributes("-transparent", True)
        self.overlay_window.attributes("-topmost", True)

        # Canvas position tracking
        self.dragging_player = False
        self.dragging_enemy = False
        self.player_pos = [200, 600]
        self.enemy_pos = [850, 600]

        # Click-through mode
        self.click_through_enabled = False

        # State tracking for Shift key temporary disable
        self._click_through_state_before_shift = False
        self._shift_pressed = False
        self._keyboard_listener = None

        # Setup UI
        self.setup_control_panel()
        self.setup_canvas()

        # Bind keyboard shortcuts to root so they work when controls are focused
        self.root.bind("<Command-t>", self.toggle_click_through)

        # Also bind to overlay in case it has focus
        self.overlay_window.bind("<Command-t>", self.toggle_click_through)

        # Setup global hotkey listener for Shift key
        self._setup_global_hotkey()

        # Initial draw
        self.update_visualization()

        # Set initial click-through UI state
        self.update_click_through_ui()

        # Position overlay window to the right of controls window
        self.root.update_idletasks()
        controls_x = self.root.winfo_x()
        controls_y = self.root.winfo_y()
        controls_width = self.root.winfo_width()
        overlay_x = controls_x + controls_width
        self.overlay_window.geometry(f"1050x850+{overlay_x}+{controls_y}")

    def on_close(self):
        """Handle application closure"""
        # Stop keyboard listener if it exists
        if self._keyboard_listener is not None:
            try:
                self._keyboard_listener.stop()
            except Exception:
                pass
        self.root.destroy()
        sys.exit(0)

    def _setup_global_hotkey(self):
        """Setup global hotkey listener for Shift key"""
        if not PYNPUT_AVAILABLE:
            return

        try:
            def on_press(key):
                """Handle key press events"""
                try:
                    # Check if Shift key (left or right)
                    if key == keyboard.Key.shift or key == keyboard.Key.shift_l or key == keyboard.Key.shift_r:
                        # Schedule UI update in main thread
                        self.root.after(0, self._on_shift_press)
                except AttributeError:
                    # Not a special key, ignore
                    pass

            def on_release(key):
                """Handle key release events"""
                try:
                    # Check if Shift key (left or right)
                    if key == keyboard.Key.shift or key == keyboard.Key.shift_l or key == keyboard.Key.shift_r:
                        # Schedule UI update in main thread
                        self.root.after(0, self._on_shift_release)
                except AttributeError:
                    # Not a special key, ignore
                    pass

            # Create listener
            self._keyboard_listener = keyboard.Listener(
                on_press=on_press,
                on_release=on_release,
                suppress=False  # Don't suppress key events, let them pass through
            )

            # Start listener in daemon thread
            self._keyboard_listener.start()

        except Exception as e:
            print(f"Warning: Could not setup global hotkey listener: {e}")
            print("Global Shift key functionality will not be available.")
            print("On macOS, you may need to grant Accessibility permissions in System Settings.")

    def setup_control_panel(self):
        """Create the control panel with input fields"""
        # Control panel now takes up the whole main window
        control_frame = ttk.Frame(self.root, padding="10")
        control_frame.pack(fill=tk.BOTH, expand=True)

        # Title
        ttk.Label(control_frame, text="Wind Settings", font=("Arial", 12, "bold")).pack(pady=5)

        # Wind Force (1-12 scale, integer steps) - Button group
        ttk.Label(control_frame, text="Wind Force (1-12):").pack(anchor=tk.W, pady=(0, 5))
        self.wind_force = tk.DoubleVar(value=5.0)

        # Create button frame with grid layout (3 rows x 4 columns)
        wind_button_frame = ttk.Frame(control_frame)
        wind_button_frame.pack(fill=tk.X, pady=0)

        # Store button references for highlighting selected button
        self.wind_force_buttons = {}

        # Create buttons for each wind level (1-12)
        for i in range(1, 13):
            row = (i - 1) // 4
            col = (i - 1) % 4

            btn = tk.Button(
                wind_button_frame,
                text=str(i),
                command=lambda level=i: self.set_wind_force(level),
                highlightthickness=1,
                pady=2
            )
            btn.grid(row=row, column=col, sticky="ew")
            self.wind_force_buttons[i] = btn

            # Configure grid weights for even spacing
            wind_button_frame.grid_columnconfigure(col, weight=1)

        # Highlight initial selected button (5)
        self.update_wind_force_button_highlight(5)

        # Wind Angle with Circular Knob
        ttk.Label(control_frame, text="Wind Direction:", font=("Arial", 10, "bold")).pack(anchor=tk.W, pady=(15, 5))

        # Create circular knob
        knob_frame = ttk.Frame(control_frame)
        knob_frame.pack(pady=2)

        self.wind_angle_knob = CircularKnob(
            knob_frame,
            size=150,
            initial_angle=90,
            command=self.on_wind_knob_change
        )
        self.wind_angle_knob.pack()

        # Store wind angle variable
        self.wind_angle = tk.DoubleVar(value=90.0)

        # Shot Angle
        ttk.Label(control_frame, text="Shot Angle (°):").pack(anchor=tk.W)
        self.shot_angle = tk.DoubleVar(value=45.0)
        ttk.Scale(control_frame, from_=0, to=90, variable=self.shot_angle,
                 orient=tk.HORIZONTAL, command=self.on_shot_angle_change).pack(fill=tk.X, pady=5)
        self.shot_angle_label = ttk.Label(control_frame, text="45.0°")
        self.shot_angle_label.pack(anchor=tk.E)

        # Shot Power UI removed as requested
        self.shot_power = tk.DoubleVar(value=0.0)

        ttk.Separator(control_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=5)

        # Transparency Settings
        ttk.Label(control_frame, text="Overlay Controls", font=("Arial", 12, "bold")).pack(pady=5)

        # Instructions for click-through shortcuts
        ttk.Label(control_frame, text="Cmd+T: Toggle Click-Through", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=0)
        ttk.Label(control_frame, text="Hold Shift: Quick Adjust Markers", font=("Arial", 9, "bold")).pack(anchor=tk.W, pady=0)

        # Explicit button for toggling
        self.click_through_button = ttk.Button(control_frame, text="Enable Click-Through", command=self.toggle_click_through)
        self.click_through_button.pack(fill=tk.X, pady=4)

        # Status label for click-through mode
        self.click_through_status_label = tk.Label(control_frame, text="✗ Click-Through: Disabled",
                                                    fg="#4a5568", font=("Arial", 9))
        self.click_through_status_label.pack(anchor=tk.W, pady=2)

        ttk.Separator(control_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=10)

        # Window Positioning Section (macOS only)
        if sys.platform == 'darwin':
            # Target window title
            ttk.Label(control_frame, text="Target Window Title:").pack(anchor=tk.W)
            self.target_window_title = tk.StringVar(value="Gunbound Legend")
            ttk.Entry(control_frame, textvariable=self.target_window_title).pack(fill=tk.X, pady=5)

            # Position offset frame
            offset_frame = ttk.Frame(control_frame)
            offset_frame.pack(fill=tk.X, pady=5)

            ttk.Label(offset_frame, text="X:").grid(row=0, column=0, sticky=tk.W)
            self.offset_x = tk.IntVar(value=0)
            ttk.Entry(offset_frame, textvariable=self.offset_x, width=12).grid(row=0, column=1, padx=5)

            ttk.Label(offset_frame, text="Y:").grid(row=0, column=2, sticky=tk.W)
            self.offset_y = tk.IntVar(value=-30)
            ttk.Entry(offset_frame, textvariable=self.offset_y, width=12).grid(row=0, column=3, padx=5)

            # Position button
            ttk.Button(control_frame, text="Position Overlay", command=self.position_overlay_to_target).pack(fill=tk.X, pady=10)

    def setup_canvas(self):
        """Create the drawing canvas on the overlay window"""
        # Canvas attached directly to overlay_window for better transparency support
        self.canvas = tk.Canvas(self.overlay_window, bg="systemTransparent", width=1050, height=850, highlightthickness=0)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Bind mouse events for dragging
        self.canvas.bind("<Button-1>", self.on_canvas_click)
        self.canvas.bind("<B1-Motion>", self.on_canvas_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_canvas_release)

    def on_wind_knob_change(self, angle):
        """Handle wind angle knob change"""
        self.wind_angle.set(angle)
        self.on_param_change()

    def set_wind_force(self, level):
        """Set wind force from button click"""
        self.wind_force.set(float(level))
        self.update_wind_force_button_highlight(level)
        self.on_param_change()

    def update_wind_force_button_highlight(self, selected_level):
        """Update button appearance to highlight selected wind force level"""
        for level, button in self.wind_force_buttons.items():
            if level == selected_level:
                # Highlight selected button with bright blue background and border
                button.configure(
                    foreground="#b91c1c",
                    highlightthickness=1,
                    highlightbackground="#b91c1c",
                )
            else:
                # Reset to default appearance
                button.configure(
                    foreground="#4a5568",
                    highlightthickness=1,
                    highlightbackground="systemTransparent",
                )

    def on_wind_force_change(self, value):
        """Handle wind force change (for programmatic updates)"""
        # Round to nearest integer
        rounded_value = round(float(value))
        self.wind_force.set(rounded_value)
        self.update_wind_force_button_highlight(int(rounded_value))
        self.on_param_change()

    def on_shot_angle_change(self, value):
        """Handle shot angle slider change with fine step resolution"""
        # Round to 0.1 degree for smooth updates
        rounded_value = round(float(value) * 10) / 10
        self.shot_angle.set(rounded_value)
        self.on_param_change()

    def set_wind_angle(self, angle):
        """Set wind angle programmatically (updates knob)"""
        self.wind_angle.set(angle)
        self.wind_angle_knob.set_angle(angle)
        self.on_param_change()

    def on_param_change(self, event=None):
        """Update labels and live trajectory when parameters change"""
        # Update labels with integer values
        current_wind_force = int(self.wind_force.get())
        self.shot_angle_label.config(text=f"{self.shot_angle.get():.1f}°")

        # Update button highlight to match current wind force
        self.update_wind_force_button_highlight(current_wind_force)

        # Live update trajectory
        self.update_visualization()

    def on_canvas_click(self, event):
        """Handle mouse click on canvas"""
        x, y = event.x, event.y

        # Check if clicking near player pointer
        if abs(x - self.player_pos[0]) < 20 and abs(y - self.player_pos[1]) < 20:
            self.dragging_player = True
        # Check if clicking near enemy pointer
        elif abs(x - self.enemy_pos[0]) < 20 and abs(y - self.enemy_pos[1]) < 20:
            self.dragging_enemy = True

    def on_canvas_drag(self, event):
        """Handle mouse drag on canvas"""
        if self.dragging_player:
            self.player_pos = [event.x, event.y]
            self.update_visualization()
        elif self.dragging_enemy:
            self.enemy_pos = [event.x, event.y]
            self.update_visualization()

    def on_canvas_release(self, event):
        """Handle mouse release"""
        self.dragging_player = False
        self.dragging_enemy = False

        # Ensure final update
        self.update_visualization()

    def _set_click_through_state(self, enabled, update_ui=True):
        """
        Set click-through state directly without toggling.

        Args:
            enabled: True to enable click-through, False to disable
            update_ui: If True, update UI elements (default True)
        """
        self.click_through_enabled = enabled

        if update_ui:
            # Update UI
            self.update_click_through_ui()

        if self.click_through_enabled:
            # Enable click-through mode

            # Platform-specific: Enable click-through on macOS
            if sys.platform == 'darwin':
                try:

                    # Use PyObjC to access macOS NSWindow API
                    from Cocoa import NSApp  # type: ignore

                    # Let's try applying to all windows that match the overlay dimensions or just apply to the last created one
                    for window in NSApp.windows():

                        # Heuristic: The main window has title "Aim Controls"
                        if window.title() != "Aim Controls":
                             window.setIgnoresMouseEvents_(True)

                except Exception as e:
                    print(f"Could not enable click-through: {e}")
                    print("Note: Install PyObjC with: pip install pyobjc-framework-Cocoa")
        else:

            # Platform-specific: Disable click-through on macOS
            if sys.platform == 'darwin':
                try:

                    from Cocoa import NSApp  # type: ignore

                    for window in NSApp.windows():
                        # Re-enable events for all windows (safe for control window too as it defaults to False)
                        # or just target the transparent ones
                        window.setIgnoresMouseEvents_(False)

                except Exception as e:
                    print(f"Could not disable click-through: {e}")

    def toggle_click_through(self, event=None):
        """Toggle click-through mode to see through and interact with windows behind"""
        self._set_click_through_state(not self.click_through_enabled, update_ui=True)

    def _on_shift_press(self, key=None):
        """Handle Shift key press - temporarily disable click-through if enabled"""
        # Only handle if not already processing a shift press
        if self._shift_pressed:
            return

        # Check if click-through is currently enabled
        if self.click_through_enabled:
            # Store the state before disabling
            self._click_through_state_before_shift = True
            self._shift_pressed = True
            # Disable click-through without updating UI (silent disable)
            self._set_click_through_state(False, update_ui=False)
            # Update UI to show Shift-held state
            self.update_click_through_ui()
        else:
            # Click-through wasn't enabled, so don't do anything
            self._click_through_state_before_shift = False
            self._shift_pressed = True

    def _on_shift_release(self, key=None):
        """Handle Shift key release - restore click-through if it was enabled before"""
        if not self._shift_pressed:
            return

        # If click-through was enabled before shift was pressed, restore it
        if self._click_through_state_before_shift:
            self._set_click_through_state(True, update_ui=False)

        # Reset state flags
        self._shift_pressed = False
        self._click_through_state_before_shift = False

        # Update UI to reflect restored state
        self.update_click_through_ui()

    def update_click_through_ui(self):
        """Update UI elements to reflect current click-through state"""
        if self._shift_pressed and self._click_through_state_before_shift:
            # Shift is being held, temporarily disabled
            self.click_through_button.config(text="Disable Click-Through")
            self.click_through_status_label.config(text="⇧ Shift Held: Temporarily Disabled", fg="#ecc94b")
        elif self.click_through_enabled:
            self.click_through_button.config(text="Disable Click-Through")
            self.click_through_status_label.config(text="✓ Click-Through: Enabled", fg="#48bb78")
        else:
            self.click_through_button.config(text="Enable Click-Through")
            self.click_through_status_label.config(text="✗ Click-Through: Disabled", fg="#4a5568")

    def get_shot_direction(self):
        """Return horizontal direction based on target position."""
        return 1 if self.enemy_pos[0] >= self.player_pos[0] else -1

    def calculate_trajectory(self, override_wind_force=None, override_wind_angle=None, override_power=None,
                             override_direction=None):
        """
        Calculate projectile trajectory with wind effect using Euler integration.
        Matches the physics model from claude.py for accurate trajectory prediction.

        Parameters available:
        - self.wind_force.get(): Wind force (1-12, Gunbound scale)
        - self.wind_angle.get(): Wind direction in degrees (0-360)
        - self.shot_angle.get(): Shot angle in degrees (0-90, where 0 is horizontal right, 90 is straight up)
        - self.shot_power.get(): Shot power (0-400)
        - self.player_pos: Starting position [x, y]

        Returns:
        - List of [x, y] coordinates for the trajectory path

        Physics Model (from claude.py):
        - Uses Euler integration for continuous acceleration effects
        - Wind is applied as continuous acceleration (not just velocity)
        - Power scaled by 2 for proper velocity mapping
        - Wind acceleration scaled by 0.8 for Gunbound-style physics
        """
        trajectory = []
        start_x, start_y = self.player_pos

        # Get input parameters
        shot_angle = self.shot_angle.get()

        # Use overrides if provided, otherwise use current settings
        power = override_power if override_power is not None else self.shot_power.get()
        wind_force = override_wind_force if override_wind_force is not None else self.wind_force.get()
        wind_angle = override_wind_angle if override_wind_angle is not None else self.wind_angle.get()
        direction = override_direction if override_direction is not None else self.get_shot_direction()

        # Physics Constants (matching claude.py)
        GRAVITY = 9.8  # m/s²
        TIME_STEP = 0.01  # seconds (matching claude.py)
        MAX_TIME = 60.0  # maximum simulation time

        # Convert angles to radians
        shot_radians = math.radians(shot_angle)
        wind_radians = math.radians(wind_angle)

        # Initial velocity (scale power to velocity - matching claude.py)
        v0 = power * 0.5  # m/s
        vx = v0 * math.cos(shot_radians) * direction
        vy = v0 * math.sin(shot_radians)

        # Wind acceleration components (scaled appropriately - matching claude.py)
        wind_accel = wind_force * 0.1  # m/s²
        wind_ax = wind_accel * math.cos(wind_radians)
        wind_ay = wind_accel * math.sin(wind_radians)

        # Initialize position
        x, y = 0.0, 0.0
        t = 0.0

        # Simulate until projectile goes out of bounds
        while t < MAX_TIME:
            # Convert to canvas coordinates and store
            screen_x = start_x + x
            screen_y = start_y - y  # Invert Y for canvas
            trajectory.append([screen_x, screen_y])

            # Stop if projectile goes too far out of bounds
            if screen_x > 1050 or screen_x < -400 or screen_y > 850 or screen_y < -300:
                break

            # Update velocities (Euler integration - matching claude.py)
            vx += wind_ax * TIME_STEP
            vy += wind_ay * TIME_STEP
            vy -= GRAVITY * TIME_STEP  # Gravity always pulls down

            # Update position
            x += vx * TIME_STEP
            y += vy * TIME_STEP

            # Update time
            t += TIME_STEP

        return trajectory

    def update_visualization(self):
        """Update the canvas with all visual elements"""
        # Automatically calculate required power first
        self.solve_for_power()

        self.canvas.delete("all")

        # Draw player pointer (green)
        px, py = self.player_pos
        self.canvas.create_oval(px-6, py-6, px+6, py+6, fill="#48bb78", outline="#2f855a", width=3)

        # Draw enemy pointer (red)
        ex, ey = self.enemy_pos
        self.canvas.create_oval(ex-6, ey-6, ex+6, ey+6, fill="#f56565", outline="#c53030", width=3)

        # Draw zero-wind trajectory (baseline) using the CALCULATED power
        # This shows "where would this shot land if there was 0 wind?"
        zero_wind_trajectory = self.calculate_trajectory(override_wind_force=0)
        if len(zero_wind_trajectory) > 1:
            # Draw trajectory line in red
            for i in range(len(zero_wind_trajectory) - 1):
                x1, y1 = zero_wind_trajectory[i]
                x2, y2 = zero_wind_trajectory[i + 1]
                self.canvas.create_line(x1, y1, x2, y2, fill="#fc8181", width=2, dash=(6, 4))

            # Draw predicted landing point for zero wind
            last_x, last_y = zero_wind_trajectory[-1]
            self.canvas.create_oval(last_x-6, last_y-6, last_x+6, last_y+6,
                                   outline="#fc8181", width=1, dash=(6, 4))

        # Draw trajectory (this uses the calculated power from solve_for_power)
        trajectory = self.calculate_trajectory()
        if len(trajectory) > 1:
            # Draw trajectory line
            for i in range(len(trajectory) - 1):
                x1, y1 = trajectory[i]
                x2, y2 = trajectory[i + 1]
                # Color gradient from green to yellow based on position
                progress = i / len(trajectory)
                color = self.interpolate_color("#22c55e", "#2563eb", progress)
                self.canvas.create_line(x1, y1, x2, y2, fill=color, width=1)

            # Draw predicted landing point
            last_x, last_y = trajectory[-1]
            self.canvas.create_oval(last_x-8, last_y-8, last_x+8, last_y+8,
                                    outline="#ecc94b", width=2)

        # Calculate and display distance
        ex, ey = self.enemy_pos
        px, py = self.player_pos
        distance = math.sqrt((ex - px)**2 + (ey - py)**2)
        self.canvas.create_text((px + ex) / 2, (py + ey) / 2 - 20,
                               text=f"Distance: {distance:.1f}px",
                               fill="#cbd5e0", font=("Arial", 9))

        # Draw wind indicator
        self.draw_wind_indicator()

    def solve_for_power(self):
        """
        Linearly increase power to find the best shot.
        Stops when trajectory hits the target or starts moving away (local minimum).
        Updates self.shot_power.
        """
        ex, ey = self.enemy_pos
        px, py = self.player_pos  # Need these for distance calculation too

        # Search parameters
        start_p = 0.0
        max_p = 400.0
        step_p = 1.0  # Resolution of power search

        best_p = 0.0
        min_dist = float('inf')

        # Tolerance for "hit" (in pixels) - allows missing a little bit
        HIT_TOLERANCE = 0.0

        try:
            # Linear scan from 0 to max_p
            # We use a while loop to handle float steps easily
            current_p = start_p
            while current_p <= max_p:
                # Simulate with this power
                traj = self.calculate_trajectory(override_power=current_p)

                if not traj:
                    current_p += step_p
                    continue

                # Calculate minimum distance from this trajectory to the enemy
                # We check every point in the trajectory to find the closest pass
                current_traj_min_dist = float('inf')
                for tx, ty in traj:
                    d_sq = (tx - ex)**2 + (ty - ey)**2
                    if d_sq < current_traj_min_dist:
                        current_traj_min_dist = d_sq

                current_dist = math.sqrt(current_traj_min_dist)

                # Check for "Hit"
                if current_dist <= HIT_TOLERANCE:
                    best_p = current_p
                    break # Found a valid shot, stop searching

                # Check for Local Minimum (closest point)
                if current_dist < min_dist:
                    # We are getting closer
                    min_dist = current_dist
                    best_p = current_p
                elif current_dist > min_dist + 1.0: # Add slight buffer for noise
                    # We have passed the closest point and are moving away
                    # The previous point (best_p) was a local minimum
                    break

                current_p += step_p

            # Set the best power found
            self.shot_power.set(best_p)

        except Exception as e:
            print(f"Error in auto-aim: {e}")

        # Calculate and display distance
        distance = math.sqrt((ex - px)**2 + (ey - py)**2)
        self.canvas.create_text((px + ex) / 2, (py + ey) / 2 - 20,
                               text=f"Distance: {distance:.1f}px",
                               fill="#cbd5e0", font=("Arial", 9))

        # Draw wind indicator
        self.draw_wind_indicator()


    def draw_wind_indicator(self):
        """Draw a visual wind direction arrow"""
        wind_force = self.wind_force.get()
        wind_angle = self.wind_angle.get()

        # Position in center of overlay window
        center_x, center_y = 525, 72
        arrow_length = 25

        # Calculate arrow end point
        angle_rad = math.radians(wind_angle)
        end_x = center_x + arrow_length * math.cos(angle_rad)
        end_y = center_y - arrow_length * math.sin(angle_rad)  # Invert Y for canvas

        # Draw arrow circle background
        self.canvas.create_oval(center_x-35, center_y-35, center_x+35, center_y+35,
                               outline="#ef4444", width=2)

        # Draw arrow line
        self.canvas.create_line(center_x, center_y, end_x, end_y,
                               fill="#ef4444", width=2, arrow=tk.LAST)

        # Draw wind force text (as integer, like Gunbound)
        self.canvas.create_text(center_x, center_y+50, text=f"Wind: {int(wind_force)}",
                               fill="#ef4444", font=("Arial", 10, "bold"))

    def interpolate_color(self, color1, color2, t):
        """Interpolate between two hex colors"""
        # Parse hex colors
        r1, g1, b1 = int(color1[1:3], 16), int(color1[3:5], 16), int(color1[5:7], 16)
        r2, g2, b2 = int(color2[1:3], 16), int(color2[3:5], 16), int(color2[5:7], 16)

        # Interpolate
        r = int(r1 + (r2 - r1) * t)
        g = int(g1 + (g2 - g1) * t)
        b = int(b1 + (b2 - b1) * t)

        return f"#{r:02x}{g:02x}{b:02x}"

    def find_window_by_title(self, target_title):
        """
        Find a window by its title on macOS.
        Returns window info dict with keys: window_id, title, x, y, width, height
        or None if not found.
        """
        if sys.platform != 'darwin':
            self.position_status.set("Window detection only works on macOS")
            return None

        try:
            window_list = CGWindowListCopyWindowInfo(
                kCGWindowListOptionOnScreenOnly,
                kCGNullWindowID
            )

            for window_info in window_list:
                window_title = window_info.get('kCGWindowName', '')
                if window_title and target_title.lower() in window_title.lower():
                    bounds = window_info.get('kCGWindowBounds', {})
                    if bounds:
                        return {
                            'window_id': window_info.get('kCGWindowNumber'),
                            'title': window_title,
                            'x': int(bounds['X']),
                            'y': int(bounds['Y']),
                            'width': int(bounds['Width']),
                            'height': int(bounds['Height'])
                        }

            self.position_status.set(f"No window found with title '{target_title}'")
            return None

        except Exception as e:
            self.position_status.set(f"Error finding window: {e}\n\nGrant Accessibility permissions in System Settings → Privacy & Security")
            return None

    def position_overlay_to_target(self):
        """
        Position the overlay window relative to a target window.
        Uses window title and offset values from UI controls.
        """
        target_title = self.target_window_title.get()
        offset_x = self.offset_x.get()
        offset_y = self.offset_y.get()

        # Find the target window
        target_window = self.find_window_by_title(target_title)

        if target_window:
            # Calculate new position
            new_x = target_window['x'] + offset_x
            new_y = target_window['y'] + offset_y

            # Get current overlay geometry to extract width and height
            current_geometry = self.overlay_window.geometry()
            width, height = current_geometry.split('+')[0].split('x')

            # Update overlay window position
            self.overlay_window.geometry(f"{width}x{height}+{new_x}+{new_y}")
        else:
            # Error message already set in find_window_by_title
            pass


def main():
    root = tk.Tk()
    app = GunboundAimAssistant(root)
    root.mainloop()


if __name__ == "__main__":
    main()
