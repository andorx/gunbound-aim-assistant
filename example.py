import math

def calculate_power (distance, angle, wind, gravity=9.8):
    """
    Calculate the power needed to hit an enemy in Gunbound.

    Args:
    distance (float): Distance to the enemy (in meters or game units).
    angle (float): Shooting angle in degrees.
    wind (float): Wind strength (positive for tailwind, negative for headwind).
    gravity (float): Gravity constant (default is 9.8 m/s^2).

    Returns:
    float: The required power (0-100 scale).
    """

    # Convert angle to radians
    angle_rad = math. radians(angle)

    # Adjust effective distance based on wind (simplified formula)
    effective_distance = distance - (wind * 0.5 * math.cos(angle_rad))

    if effective_distance <= 0:
        raise ValueError("Target is too close or wind is too strong in the opposite direction!")

    # Calculate the initial velocity required using projectile motion formula
    try:
        initial_velocity = math.sqrt((effective_distance * gravity) / (math.sin(2 * angle_rad)))
    except ValueError:
        raise ValueError("Angle or distance is invalid for this calculation.")

    # Map the initial velocity to a 0-100 power scale (assumes max velocity at power 100 is 100 m/s)
    max_velocity = 100.0 # Example max velocity for full power
    power = (initial_velocity / max_velocity) * 100

    # Clamp the power to 0-100 range
    power = max(0, min(power, 100))

    return power
