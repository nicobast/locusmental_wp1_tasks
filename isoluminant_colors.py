# Define isoluminant colors
isoluminant_colors = {
    "green": (0, 130, 0),
    "red": (255, 0, 0),
    "yellow": (86,86, 0)
}

# Luminance function based on the RGB values
def calculate_luminance(R, G, B):
    return 0.299 * R + 0.587 * G + 0.114 * B

# Calculate the luminance of green, red, and yellow
luminance_green = calculate_luminance(*isoluminant_colors["green"])
print(f"Luminance of green: {luminance_green}")
luminance_red = calculate_luminance(*isoluminant_colors["red"])
print(f"Luminance of red: {luminance_red}")
luminance_yellow = calculate_luminance(*isoluminant_colors["yellow"])
print(f"Luminance of yellow: {luminance_yellow}")

# Calculate average luminance (so the grey will match the average luminance)
average_luminance = (luminance_green + luminance_red + luminance_yellow) / 3
print(f"Average luminance: {average_luminance}")

# Now, create a grey color that matches the average luminance
# We assume the grey color will have equal R, G, and B values
# To match the average luminance, find an appropriate R (which will be the same for G and B)
def find_grey_for_luminance(target_luminance):
    # Try different values for grey R, and adjust until the luminance matches
    # We will simply iterate to find the grey value that gives the correct luminance
    for R in range(0, 256):
        G = B = R
        if abs(calculate_luminance(R, G, B) - target_luminance) < 1:  # Close enough to match
            return (R, G, B)
    return (128, 128, 128)  # Default grey if no exact match found

# Find the grey color for the average luminance
grey_color = find_grey_for_luminance(average_luminance)

# Print out the values
print(f"Grey color (isoluminant): {grey_color}")

# Add grey to the isoluminant colors dictionary
isoluminant_colors["grey"] = grey_color

normalize_grey = [x/255 for x in grey_color] # Normalize the grey color for values  from 0 to 1
print(f"Grey color (normalized): {normalize_grey}")
# Now you can use this grey in your experiment
print(isoluminant_colors)
