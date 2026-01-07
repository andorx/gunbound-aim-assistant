#!/usr/bin/env python3
"""
Gunbound Mobile Aim Assistant
An overlay tool to help with aiming calculations and trajectory visualization
"""

import tkinter as tk
from tkinter import ttk
import math


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

        # Draw tick marks every 45 degrees
        for tick_angle in range(0, 360, 45):
            angle_rad = math.radians(tick_angle)
            x1 = self.center_x + (self.radius - 5) * math.cos(angle_rad)
            y1 = self.center_y - (self.radius - 5) * math.sin(angle_rad)
            x2 = self.center_x + (self.radius - 10) * math.cos(angle_rad)
            y2 = self.center_y - (self.radius - 10) * math.sin(angle_rad)
            self.create_line(x1, y1, x2, y2, fill="#718096", width=2)

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

        # Draw angle text in center
        self.create_text(
            self.center_x, self.center_y,
            text=f"{self.angle:.0f}°", fill="#e2e8f0",
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

        self.angle = angle
        self.draw_knob()

        # Call command if provided
        if self.command:
            self.command(self.angle)

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
        self.root.title("Gunbound Aim Assistant")
        self.root.geometry("1000x700")

        # Canvas position tracking
        self.dragging_player = False
        self.dragging_enemy = False
        self.player_pos = [200, 500]  # [x, y] for player gun barrel
        self.enemy_pos = [600, 500]   # [x, y] for enemy tank

        # Setup UI
        self.setup_control_panel()
        self.setup_canvas()

        # Initial draw
        self.update_visualization()

    def setup_control_panel(self):
        """Create the control panel with input fields"""
        control_frame = ttk.Frame(self.root, padding="10")
        control_frame.pack(side=tk.LEFT, fill=tk.Y)

        # Title
        ttk.Label(control_frame, text="Wind Settings", font=("Arial", 12, "bold")).pack(pady=5)

        # Wind Force (1-12 scale, integer steps)
        ttk.Label(control_frame, text="Wind Force (1-12):").pack(anchor=tk.W)
        self.wind_force = tk.DoubleVar(value=5.0)
        self.wind_force_slider = tk.Scale(control_frame, from_=1, to=12, variable=self.wind_force,
                                          orient=tk.HORIZONTAL, command=self.on_param_change,
                                          resolution=1, showvalue=0, highlightthickness=0)
        self.wind_force_slider.pack(fill=tk.X, pady=5)
        self.wind_force_label = ttk.Label(control_frame, text="5")
        self.wind_force_label.pack(anchor=tk.E)

        # Wind Angle with Circular Knob
        ttk.Label(control_frame, text="Wind Direction:", font=("Arial", 10, "bold")).pack(anchor=tk.W, pady=(15, 5))

        # Create circular knob
        knob_frame = ttk.Frame(control_frame)
        knob_frame.pack(pady=5)

        self.wind_angle_knob = CircularKnob(
            knob_frame,
            size=150,
            initial_angle=90,
            command=self.on_wind_knob_change
        )
        self.wind_angle_knob.pack()

        # Store wind angle variable
        self.wind_angle = tk.DoubleVar(value=90.0)

        ttk.Separator(control_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=15)

        # Shot Settings
        ttk.Label(control_frame, text="Shot Settings", font=("Arial", 12, "bold")).pack(pady=5)

        # Shot Angle
        ttk.Label(control_frame, text="Shot Angle (°):").pack(anchor=tk.W)
        self.shot_angle = tk.DoubleVar(value=45.0)
        ttk.Scale(control_frame, from_=0, to=90, variable=self.shot_angle,
                 orient=tk.HORIZONTAL, command=self.on_param_change).pack(fill=tk.X, pady=5)
        self.shot_angle_label = ttk.Label(control_frame, text="45.0°")
        self.shot_angle_label.pack(anchor=tk.E)

        # Shot Power
        ttk.Label(control_frame, text="Shot Power:").pack(anchor=tk.W, pady=(10, 0))
        self.shot_power = tk.DoubleVar(value=200.0)
        ttk.Scale(control_frame, from_=0, to=400, variable=self.shot_power,
                 orient=tk.HORIZONTAL, command=self.on_param_change).pack(fill=tk.X, pady=5)
        self.shot_power_label = ttk.Label(control_frame, text="200.0")
        self.shot_power_label.pack(anchor=tk.E)

        ttk.Separator(control_frame, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=10)

        # Results display
        ttk.Label(control_frame, text="Calculated Results", font=("Arial", 12, "bold")).pack(pady=5)
        self.results_label = ttk.Label(control_frame, text="Adjust parameters above",
                                      wraplength=180)
        self.results_label.pack(anchor=tk.W, pady=5)

    def setup_canvas(self):
        """Create the drawing canvas"""
        canvas_frame = ttk.Frame(self.root, padding="10")
        canvas_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.canvas = tk.Canvas(canvas_frame, bg="#1a1a2e", width=700, height=650)
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # Bind mouse events for dragging
        self.canvas.bind("<Button-1>", self.on_canvas_click)
        self.canvas.bind("<B1-Motion>", self.on_canvas_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_canvas_release)

        # Draw ground line reference
        self.canvas.create_line(0, 550, 800, 550, fill="#4a5568", width=2, dash=(5, 5))

    def on_wind_knob_change(self, angle):
        """Handle wind angle knob change"""
        self.wind_angle.set(angle)
        self.on_param_change()

    def set_wind_angle(self, angle):
        """Set wind angle programmatically (updates knob)"""
        self.wind_angle.set(angle)
        self.wind_angle_knob.set_angle(angle)
        self.on_param_change()

    def on_param_change(self, event=None):
        """Update labels and live trajectory when parameters change"""
        # Update labels with integer values
        self.wind_force_label.config(text=f"{int(self.wind_force.get())}")
        self.shot_angle_label.config(text=f"{self.shot_angle.get():.1f}°")
        self.shot_power_label.config(text=f"{self.shot_power.get():.1f}")

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

    def calculate_trajectory(self):
        """
        Calculate projectile trajectory with wind effect.

        This is where YOU will implement the physics calculation!
        The function should return a list of (x, y) points representing the trajectory.

        Parameters available:
        - self.wind_force.get(): Wind force (1-12, Gunbound scale)
        - self.wind_angle.get(): Wind direction in degrees (0-360)
        - self.shot_angle.get(): Shot angle in degrees (0-90, where 0 is horizontal right, 90 is straight up)
        - self.shot_power.get(): Shot power (0-400)
        - self.player_pos: Starting position [x, y]

        Returns:
        - List of [x, y] coordinates for the trajectory path

        Tips:
        - Use physics formulas for projectile motion
        - Wind affects both horizontal and vertical velocity
        - Consider gravity (typically around 9.8 or scaled for game)
        - Different wind angles affect trajectory differently
        - Gunbound wind 1-12 scale means higher values = stronger wind effect
        """
        # TODO: Implement the trajectory calculation here
        # For now, returning a placeholder straight line
        trajectory = []
        start_x, start_y = self.player_pos

        # Placeholder: Simple parabolic without wind
        # Replace this with your actual physics calculation!
        power = self.shot_power.get()
        angle_rad = math.radians(self.shot_angle.get())

        # Initial velocity components
        vx = power * math.cos(angle_rad) * 0.1
        vy = -power * math.sin(angle_rad) * 0.1  # Negative because canvas Y is inverted

        # Simple physics loop
        x, y = start_x, start_y
        dt = 0.5  # Time step
        gravity = 2.0  # Gravity constant

        for t in range(100):
            trajectory.append([x, y])

            # Update position
            x += vx * dt
            y += vy * dt

            # Apply gravity
            vy += gravity * dt

            # Stop if off screen
            if x > 800 or y > 700:
                break

        return trajectory

    def calculate_wind_correction(self):
        """
        Calculate suggested angle/power adjustments for wind.

        This is where YOU can implement wind correction logic!
        The function should return adjustment suggestions.

        Returns:
        - Dictionary with 'angle_adjustment' and 'power_adjustment' suggestions
        """
        # TODO: Implement wind correction calculation
        # This should analyze how much to adjust your shot based on wind

        wind_force = self.wind_force.get()
        wind_angle = self.wind_angle.get()

        # Placeholder logic - replace with your calculation!
        angle_adj = 0
        power_adj = 0

        return {
            'angle_adjustment': angle_adj,
            'power_adjustment': power_adj,
            'wind_effect': f"Wind {wind_force} at {wind_angle}°"
        }

    def update_visualization(self):
        """Update the canvas with all visual elements"""
        self.canvas.delete("all")

        # Draw ground reference line
        self.canvas.create_line(0, 550, 800, 550, fill="#4a5568", width=2, dash=(5, 5))
        self.canvas.create_text(400, 565, text="Ground Reference", fill="#4a5568", font=("Arial", 8))

        # Draw distance reference
        self.canvas.create_text(50, 20, text="Scale: 100px ≈ 1 screen distance",
                               fill="#718096", font=("Arial", 8))

        # Draw player pointer (green)
        px, py = self.player_pos
        self.canvas.create_oval(px-15, py-15, px+15, py+15, fill="#48bb78", outline="#2f855a", width=3)
        self.canvas.create_text(px, py-25, text="YOU", fill="#48bb78", font=("Arial", 10, "bold"))

        # Draw enemy pointer (red)
        ex, ey = self.enemy_pos
        self.canvas.create_oval(ex-15, ey-15, ex+15, ey+15, fill="#f56565", outline="#c53030", width=3)
        self.canvas.create_text(ex, ey-25, text="ENEMY", fill="#f56565", font=("Arial", 10, "bold"))

        # Draw trajectory
        trajectory = self.calculate_trajectory()
        if len(trajectory) > 1:
            # Draw trajectory line
            for i in range(len(trajectory) - 1):
                x1, y1 = trajectory[i]
                x2, y2 = trajectory[i + 1]
                # Color gradient from green to yellow based on position
                progress = i / len(trajectory)
                color = self.interpolate_color("#48bb78", "#ecc94b", progress)
                self.canvas.create_line(x1, y1, x2, y2, fill=color, width=2)

            # Draw predicted landing point
            last_x, last_y = trajectory[-1]
            self.canvas.create_oval(last_x-8, last_y-8, last_x+8, last_y+8,
                                   outline="#ecc94b", width=2)

        # Calculate and display distance
        distance = math.sqrt((ex - px)**2 + (ey - py)**2)
        self.canvas.create_text((px + ex) / 2, (py + ey) / 2 - 20,
                               text=f"Distance: {distance:.1f}px",
                               fill="#cbd5e0", font=("Arial", 9))

        # Draw wind indicator
        self.draw_wind_indicator()

        # Update results label
        correction = self.calculate_wind_correction()
        results_text = f"""Distance: {distance:.1f} px

{correction['wind_effect']}

Angle Adjustment:
{correction['angle_adjustment']:+.1f}°

Power Adjustment:
{correction['power_adjustment']:+.1f}"""
        self.results_label.config(text=results_text)

    def draw_wind_indicator(self):
        """Draw a visual wind direction arrow"""
        wind_force = self.wind_force.get()
        wind_angle = self.wind_angle.get()

        # Position in top-right corner
        center_x, center_y = 650, 80
        arrow_length = 30

        # Calculate arrow end point
        angle_rad = math.radians(wind_angle)
        end_x = center_x + arrow_length * math.cos(angle_rad)
        end_y = center_y - arrow_length * math.sin(angle_rad)  # Invert Y for canvas

        # Draw arrow circle background
        self.canvas.create_oval(center_x-40, center_y-40, center_x+40, center_y+40,
                               fill="#2d3748", outline="#4a5568", width=2)

        # Draw arrow line
        self.canvas.create_line(center_x, center_y, end_x, end_y,
                               fill="#63b3ed", width=3, arrow=tk.LAST)

        # Draw wind force text (as integer, like Gunbound)
        self.canvas.create_text(center_x, center_y+50, text=f"Wind: {int(wind_force)}",
                               fill="#63b3ed", font=("Arial", 10, "bold"))

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


def main():
    root = tk.Tk()
    app = GunboundAimAssistant(root)
    root.mainloop()


if __name__ == "__main__":
    main()
