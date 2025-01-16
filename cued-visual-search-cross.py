# Import necessary modules
from psychopy import visual, core, event, sound, gui, data
import random
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path( "data", "cued_visual_search", "logging_data").resolve()
filename_visual_search = os.path.join(logging_path, formatted_datetime)

logging.basicConfig(
    level = logging.DEBUG,
    filename = filename_visual_search,
    filemode = 'w', # w = write, for each subject an separate log file.
    format = '%(asctime)s:%(levelname)s:%(name)s:%(message)s')
    
print("THIS IS CUED VISUAL SEARCH.")
logging.info('THIS IS CUED VISUAL SEARCH.')

# Path to output data:
path_to_data = Path( "data", "cued_visual_search").resolve()
trials_data_folder = Path(path_to_data, 'trialdata')
eyetracking_data_folder = Path(path_to_data, 'eyetracking')
print(trials_data_folder)
print(eyetracking_data_folder)
logging.info(f'{trials_data_folder}')
logging.info(f'{eyetracking_data_folder}')

# Create a dialog box for participant info
exp_info = {
    "Participant ID": "",
    "Timepoint": ["test", "pilot", "T1", "T2", "T3"]
}

dlg = gui.DlgFromDict(
    dictionary=exp_info,
    title= "Cued Visual Search Task",
    order=["Participant ID", "Timepoint"] # Order of fields
   
)
if not dlg.OK:
    logging.warning("Experiment canceled by the user.")
    core.quit()

participant_id = exp_info["Participant ID"]
timepoint = exp_info["Timepoint"][0]

logging.info(f"Participant ID: {participant_id}")
logging.info(f"Timepoint: {timepoint}")

# Name for output data:
fileName = f'cued_visual_search{exp_info["Participant ID"]}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# Experiment handler saves experiment data automatically.
exp = data.ExperimentHandler(
    name = "cued_visual_search",
    version = '0.1',
    #extraInfo = settings,
    dataFileName = str(trials_data_folder / fileName),
    )
str(trials_data_folder / fileName)

# Initialize window and visual components
win = visual.Window(
    size=[2560, 1440],  # Set resolution to match monitor
    color="grey",
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

# Create a beep sound
beep = sound.Sound(value="A", secs=0.2)

# Refresh rate (assume 60Hz monitor)
refresh_rate = 60
frame_duration = 1 / refresh_rate

# Number of trials
num_trials = 30

# Trial loop
for trial in range(num_trials):
    # Random fixation duration between 1-1.5s
    fixation_duration = random.uniform(1, 1.5)
    num_fixation_frames = round(fixation_duration / frame_duration)

    # Draw fixation cross
    fixation = visual.ShapeStim(
        win=win,
        vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
        lineWidth=5,
        closeShape=False,
        lineColor="black"
    )

    for frameN in range(num_fixation_frames):
        fixation.draw()
        win.flip()

    # After fixation, 400 ms interval for delay and beep
    auditory_cue = random.random() < 0.5
    print(f"Trial {trial + 1}: Beep {'Played' if auditory_cue else 'Not Played'}")

    if auditory_cue:
        delay_after_fixation = random.uniform(0, 0.1)  # 0-100 ms delay
        beep_duration = random.uniform(0.2, 0.3)  # Beep duration (200-300 ms)

        # Ensure total duration fits within the 400ms interval
        remaining_interval = 0.4 - (delay_after_fixation + beep_duration)
        if remaining_interval < 0:
            print("Warning: Beep timing exceeded 400 ms window. Adjusting beep duration.")
            beep_duration = 0.4 - delay_after_fixation
            remaining_interval = 0

        # Frames for each phase
        num_delay_frames = round(delay_after_fixation / frame_duration)
        num_beep_frames = round(beep_duration / frame_duration)
        num_remaining_frames = round(remaining_interval / frame_duration)

        # Delay phase
        for frameN in range(num_delay_frames):
            win.flip()

        # Play beep
        next_flip = win.getFutureFlipTime(clock='ptb')
        beep.play(when=next_flip)
        for frameN in range(num_beep_frames):
            win.flip()
        beep.stop()
        print(f"Beep played for {beep_duration:.3f} seconds")
        
        # Fill the remaining time
        for frameN in range(num_remaining_frames):
            win.flip()

    else:
        # If no beep, just wait for 400ms
        num_wait_frames = round(0.4 / frame_duration)
        for frameN in range(num_wait_frames):
            win.flip()

    # Visual stimuli: Present shapes
    base_color = random.choice(["red", "yellow", "#00FF00"])
    odd_color = random.choice([c for c in ["red", "yellow", "#00FF00"] if c != base_color])

    # Randomize circle colors and positions
    circle_colors = [base_color] * 4
    odd_index = random.randint(0, 3)
    circle_colors[odd_index] = odd_color

    for circle, color in zip(circles, circle_colors):
        circle.fillColor = color

    # Present circles on the screen for 3 seconds
    num_visual_frames = round(3 / frame_duration)
    for frameN in range(num_visual_frames):
        for circle in circles:
            circle.draw()
        win.flip()

    # Check for 'escape' key press to exit
    keys = event.getKeys(keyList=['escape'])
    if keys and 'escape' in keys:
        break

# Close the window and quit
win.close()
core.quit()
