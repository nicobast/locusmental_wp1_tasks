# Cued Visual Search Task (Beep)
# Implements the version in the paper with simple alerting cue

# Visual Stimuli Set Up
# four circles in an imaginary circle
# colors: red, yellow and green
# in every trial 3 shapes share a common color and the fourth shape has an odd color(= target)
# duration : 3s

# fixation cross (in the paper they used animated figures)
#   duration: random btw. 1-1,5 s 
#   interval after the cross disappear and before stimuli onset =  400ms 

# Alerting Cue
# Beep (originally in the paper two alerting cues: simple (beep) and vocal (vowel))
#   - duration: random btw 200-300ms
#   - presented after the fixation cross
#   - presentes at a variable interval btw 400-80 ms before visual stimuli onset
#   - set up for 50% of the trials, randomly

# Terminal Output during task:
# Trial Nr, Bepp Played/Not Played in the trial, if played delay in ms

# before running the code
# change resolution (line 33)

# Import necessary modules
from psychopy import visual, core, event, sound
import random

# Initialize window and visual components
win = visual.Window(
    size=[2560, 1440],  # Set resolution to match monitor
    color="white",
    units="pix"
)

# Define circle positions 
circle_positions = [
    (0, 400),  # Top
    (400, 0),  # Right
    (0, -400), # Bottom
    (-400, 0)  # Left
]

# Create circle stimuli
circles = [visual.Circle(win, radius=100, fillColor=None, lineColor=None, pos=pos) for pos in circle_positions]

# Create a beep sound (set to 200ms default, will be adjusted later)
beep = sound.Sound(value="A", secs=0.2)

# Number of trials
num_trials = 16

# Trial loop
for trial in range(num_trials):
    fixation_duration = random.uniform(1, 1.5) # random duration btw 1-1,5 s
    fixation = visual.ShapeStim(
    win=win,
    vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
    lineWidth=5,
    closeShape=False,
    lineColor="black"
)
    fixation.draw()
    win.flip()
    core.wait(fixation_duration)  # Fixation cross stays for 1 second

    # Determine if this trial includes an auditory cue (50% probability)
    auditory_cue = random.random() < 0.5
    print(f"Trial {trial + 1}: Beep {'Played' if auditory_cue else 'Not Played'}")

    if auditory_cue:
        delay_before_beep = random.uniform(0.08, 0.4)  # Random delay before beep
        beep_duration = random.uniform(0.2, 0.3)  # Random beep duration between 200ms and 300ms
        print(f"Waiting for {delay_before_beep:.3f} seconds before beep...")
        core.wait(delay_before_beep)  # Wait before the beep
        
        beep.play()  # Play the beep sound
        core.wait(beep_duration)  # Wait for the beep to finish before continuing
        beep.stop()  # Stop beep after it's finished
        print(f"Beep played for {beep_duration:.3f} seconds")

    # Visuals: After beep, proceed with visual stimuli
    base_color = random.choice(["red", "yellow", "green"])
    odd_color = random.choice([c for c in ["red", "yellow", "green"] if c != base_color])

    # Randomize circle colors and positions
    circle_colors = [base_color] * 4
    odd_index = random.randint(0, 3)
    circle_colors[odd_index] = odd_color

    for circle, color in zip(circles, circle_colors):
        circle.fillColor = color

    # Draw the circles on the screen
    for circle in circles:
        circle.draw()

    win.flip()
    core.wait(3)  # The shapes should stay on the screen for 3 seconds

    # Wait for response 
    keys = event.waitKeys(maxWait=1, keyList=['escape'])

    # Exit the experiment if 'escape' is pressed
    if keys and 'escape' in keys:
        break

# Close the window and quit
win.close()
core.quit()
