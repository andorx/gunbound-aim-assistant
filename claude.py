import math
import matplotlib.pyplot as plt

def calculate_trajectory(shot_angle, shot_power, wind_force, wind_angle):
    """
    Calculate the trajectory of a Gunbound-style projectile.
    
    Parameters:
    -----------
    shot_angle : float
        Angle of the shot in degrees (0-90)
    shot_power : float
        Power of the shot (0-100)
    wind_force : float
        Wind force (1-12, Gunbound scale)
    wind_angle : float
        Wind direction in degrees (0-360)
        0° = East, 90° = North, 180° = West, 270° = South
    
    Returns:
    --------
    list of tuples : [(x, y), ...] trajectory points in meters
    """
    # Physics constants
    GRAVITY = 9.8  # m/s²
    TIME_STEP = 0.05  # seconds
    MAX_TIME = 20  # maximum simulation time
    
    # Convert angles to radians
    shot_radians = math.radians(shot_angle)
    wind_radians = math.radians(wind_angle)
    
    # Initial velocity (scale power to velocity)
    v0 = shot_power * 2  # m/s
    vx = v0 * math.cos(shot_radians)
    vy = v0 * math.sin(shot_radians)
    
    # Wind acceleration components (scaled appropriately)
    wind_accel = wind_force * 0.8  # m/s²
    wind_ax = wind_accel * math.cos(wind_radians)
    wind_ay = wind_accel * math.sin(wind_radians)
    
    # Initialize position
    x, y = 0.0, 0.0
    t = 0.0
    
    # Store trajectory points
    trajectory = []
    
    # Simulate until projectile hits ground or goes out of bounds
    while y >= 0 and t < MAX_TIME:
        trajectory.append((x, y))
        
        # Update velocities
        vx += wind_ax * TIME_STEP
        vy += wind_ay * TIME_STEP
        vy -= GRAVITY * TIME_STEP  # Gravity always pulls down
        
        # Update position
        x += vx * TIME_STEP
        y += vy * TIME_STEP
        
        # Update time
        t += TIME_STEP
        
        # Stop if projectile goes too far out of bounds
        if x > 500 or x < -100 or y < -100:
            break
    
    return trajectory


def plot_trajectory(shot_angle, shot_power, wind_force, wind_angle):
    """
    Calculate and plot the trajectory with matplotlib.
    
    Parameters:
    -----------
    Same as calculate_trajectory()
    """
    trajectory = calculate_trajectory(shot_angle, shot_power, wind_force, wind_angle)
    
    if not trajectory:
        print("No trajectory calculated")
        return
    
    # Extract x and y coordinates
    x_coords = [point[0] for point in trajectory]
    y_coords = [point[1] for point in trajectory]
    
    # Create plot
    plt.figure(figsize=(12, 6))
    plt.plot(x_coords, y_coords, 'r-', linewidth=2, label='Trajectory')
    plt.plot(x_coords[-1], y_coords[-1], 'ro', markersize=10, label='Impact Point')
    plt.plot(0, 0, 'bs', markersize=12, label='Tank')
    
    # Draw wind arrow
    wind_radians = math.radians(wind_angle)
    arrow_length = wind_force * 5
    plt.arrow(max(x_coords) * 0.8, max(y_coords) * 0.8, 
              arrow_length * math.cos(wind_radians),
              arrow_length * math.sin(wind_radians),
              head_width=3, head_length=2, fc='blue', ec='blue', 
              linewidth=2, label=f'Wind: {wind_force} @ {wind_angle}°')
    
    # Labels and formatting
    plt.xlabel('Distance (m)', fontsize=12)
    plt.ylabel('Height (m)', fontsize=12)
    plt.title(f'Gunbound Trajectory\nAngle: {shot_angle}°, Power: {shot_power}%, '
              f'Wind: {wind_force} @ {wind_angle}°', fontsize=14)
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.axhline(y=0, color='green', linewidth=3, alpha=0.5, label='Ground')
    
    # Calculate and display distance
    distance = x_coords[-1]
    max_height = max(y_coords)
    plt.text(distance/2, max_height * 1.1, 
             f'Distance: {distance:.1f}m\nMax Height: {max_height:.1f}m',
             fontsize=11, bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    plt.show()
    
    return trajectory


# Example usage and test cases
if __name__ == "__main__":
    print("Gunbound Trajectory Calculator")
    print("=" * 50)
    
    # Example 1: Basic shot with no wind
    print("\nExample 1: 45° angle, 50% power, no wind")
    traj1 = calculate_trajectory(shot_angle=45, shot_power=50, 
                                  wind_force=1, wind_angle=0)
    print(f"Distance traveled: {traj1[-1][0]:.2f}m")
    print(f"Max height: {max(p[1] for p in traj1):.2f}m")
    
    # Example 2: Strong eastward wind
    print("\nExample 2: 45° angle, 50% power, strong east wind")
    traj2 = calculate_trajectory(shot_angle=45, shot_power=50, 
                                  wind_force=10, wind_angle=0)
    print(f"Distance traveled: {traj2[-1][0]:.2f}m")
    print(f"Wind effect: +{traj2[-1][0] - traj1[-1][0]:.2f}m")
    
    # Example 3: Strong westward wind
    print("\nExample 3: 45° angle, 50% power, strong west wind")
    traj3 = calculate_trajectory(shot_angle=45, shot_power=50, 
                                  wind_force=10, wind_angle=180)
    print(f"Distance traveled: {traj3[-1][0]:.2f}m")
    print(f"Wind effect: {traj3[-1][0] - traj1[-1][0]:.2f}m")
    
    # Example 4: Upward wind (increases range)
    print("\nExample 4: 45° angle, 50% power, upward wind")
    traj4 = calculate_trajectory(shot_angle=45, shot_power=50, 
                                  wind_force=8, wind_angle=90)
    print(f"Distance traveled: {traj4[-1][0]:.2f}m")
    print(f"Max height: {max(p[1] for p in traj4):.2f}m")
    
    # Uncomment to plot (requires matplotlib)
    print("\nGenerating plot...")
    plot_trajectory(shot_angle=45, shot_power=70, 
                    wind_force=8, wind_angle=45)