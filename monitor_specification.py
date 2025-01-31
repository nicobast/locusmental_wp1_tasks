##script to specifcy a monitor for psychopy
## needs to be adapted for every machine
## this monitor name can than be called within the scripts
from psychopy import monitors

# Create a Monitor specification
monitor_name = 'LGcenter_nico_workstation'
monitor_width = 71  # Width in cm
monitor_distance = 60  # Distance in cm

# Define the monitor
mon = monitors.Monitor(
    name=monitor_name,
    width=monitor_width,
    distance=monitor_distance
)

# Set the resolution of the monitor
mon.setSizePix([2560, 1440])

# Save the monitor settings
mon.save()