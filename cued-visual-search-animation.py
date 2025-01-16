# Import necessary modules
from psychopy import prefs
prefs.hardware['audioLib'] = ['ptb'] # PTB described as highest accuracy sound class
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)' # define audio device - DEVICE SPECIFIC
prefs.hardware['audioLatencyMode'] = 3 # high sound priority, low latency mode
prefs.general['audioSampleRate'] = 44100
from psychopy import visual, core, event, sound, monitors, gui, data
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
    color="#666666",
    units="pix"
)

# Monitor parameters are adapted to presentation PC.
# Name is saved with PsychoPy monitor manager.
# units (width, distance) are in cm.
mon = monitors.Monitor(
    name = 'Iskra_monitor_204',
    width = 59.5,
    distance = 60)


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

# Number of trials
num_trials = 30


# Randomly, when i have more animations
animation_files = [f"media/videos/1080p60/{i}.mp4" for i in range(1, 21)]

# Set frame duration based on 60Hz refresh rate
frame_duration = 1.0/60.0  # 16.67ms per frame

# Trial loop
for trial in range(num_trials):
    print(f"Starting trial {trial + 1}")
    
    # Present circles for 3 seconds (180 frames at 60Hz)
    base_color = random.choice(["red", "yellow", "#00FF00"])
    odd_color = random.choice([c for c in ["red", "yellow", "#00FF00"] if c != base_color])

    # Randomize circle colors and positions
    circle_colors = [base_color] * 4
    odd_index = random.randint(0, 3)
    circle_colors[odd_index] = odd_color

    for circle, color in zip(circles, circle_colors):
        circle.fillColor = color

    # Display circles for 3 seconds (180 frames)
    for frame in range(int(1.5 / frame_duration)):
        for circle in circles:
            circle.draw()
        win.flip()
        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

    # Clear the screen after circles
    win.flip()
    
    print(f"Trial {trial + 1}: Loading animation")
    try:
        fixation_animation = visual.MovieStim(
        win=win,
        filename=random.choice(animation_files),
        loop=False,
        noAudio=True
        )
        
        video_width, video_height = 1920, 1080
        
        
        # Set the position to center the video and ensure the original size
        fixation_animation.pos = (0, 0)
        fixation_animation.size = (video_width, video_height)
       
               
        #fixation_animation.pos = (0, 0)    

        print(f"Trial {trial + 1}: Starting animation")
        
        # Play the animation with timeout protection
        animation_start_time = core.getTime()
        animation_timeout = 5.0  # Maximum 5 seconds for animation
        fixation_animation.play()
        
        while (fixation_animation.status != visual.FINISHED and 
               core.getTime() - animation_start_time < animation_timeout):
            # Check if the animation is actually playing
            if hasattr(fixation_animation, '_player') and fixation_animation._player:
                fixation_animation.draw()
            else:
                print(f"Trial {trial + 1}: Animation player not initialized")
                break
                
            win.flip()
            
            if event.getKeys(keyList=['escape']):
                win.close()
                core.quit()
        
        print(f"Trial {trial + 1}: Animation loop completed")
        
        # Explicit cleanup
        try:
            fixation_animation.stop()
        except Exception as e:
            print(f"Trial {trial + 1}: Error stopping animation: {e}")
            
        try:
            del fixation_animation
        except Exception as e:
            print(f"Trial {trial + 1}: Error deleting animation: {e}")
            
    except Exception as e:
        print(f"Trial {trial + 1}: Animation error: {e}")
    
    # Multiple clear screens to ensure clean state
    for _ in range(3):
        win.flip()
    
    print(f"Trial {trial + 1}: Starting beep phase")
    
    # 400ms interval for delay and potential beep (24 frames at 60Hz)
    auditory_cue = random.random() < 0.5
    print(f"Trial {trial + 1}: Beep {'Played' if auditory_cue else 'Not Played'}")

    if auditory_cue:
        # Convert time intervals to frames
        delay_frames = int(random.uniform(0, 0.1) / frame_duration)
        beep_frames = int(random.uniform(0.2, 0.3) / frame_duration)
        total_frames = int(0.4 / frame_duration)
        remaining_frames = total_frames - (delay_frames + beep_frames)

        # Delay phase
        for frame in range(delay_frames):
            win.flip()

        # Play beep
        next_flip = win.getFutureFlipTime(clock='ptb')
        beep.play(when=next_flip)
        for frame in range(beep_frames):
            win.flip()
        beep.stop()

        # Remaining time
        for frame in range(remaining_frames):
            win.flip()

    else:
        # No beep - wait for 400ms (24 frames)
        for frame in range(int(0.4 / frame_duration)):
            win.flip()
    
    print(f"Trial {trial + 1}: Completed")
    
    # Ensure screen is clear before next trial
    win.flip()
    
    # Small pause between trials
    for frame in range(int(0.1 / frame_duration)):  # 100ms pause
        win.flip()

# Close the window and quit
win.close()
core.quit()