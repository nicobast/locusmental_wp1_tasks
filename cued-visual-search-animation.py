# Import necessary modules
from psychopy import prefs
prefs.hardware['audioLib'] = ['ptb'] # PTB described as highest accuracy sound class
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)' # define audio device - DEVICE SPECIFIC
prefs.hardware['audioLatencyMode'] = 3 # high sound priority, low latency mode
prefs.general['audioSampleRate'] = 44100
from psychopy.hardware import keyboard
from psychopy import visual, core, event, sound, monitors, gui, data, clock
import tobii_research as tr
from psychopy.iohub import launchHubServer
import random, numpy, time
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
import traceback
from datetime import datetime


# Define screens
PRESENTATION_SCREEN = 0
DIALOG_SCREEN = 1
current_screen = PRESENTATION_SCREEN  # Start in presentation mode

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path( "data", "cued_visual_search", "logging_data").resolve()
filename_visual_search = os.path.join(logging_path, formatted_datetime)

# Ensure required directories exist BEFORE logging
logging_path.mkdir(parents=True, exist_ok=True)

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
loggings_data_folder = Path(path_to_data, 'logging_data')

# Create folders if they don't exist
for folder in [trials_data_folder, eyetracking_data_folder, loggings_data_folder]:
    folder.mkdir(parents=True, exist_ok=True)
    
print(trials_data_folder)
print(eyetracking_data_folder)
print(loggings_data_folder)

logging.info(f'{trials_data_folder}')
logging.info(f'{eyetracking_data_folder}')
logging.info(f'{loggings_data_folder}')

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
fileName = f'cued_visual_search{exp_info["Participant ID"]}_{timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
testmode_et = True
sampling_rate = 60 # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
background_color_rgb = (.3,.3,.3) # RGB values for grey background
size_fixation_cross_in_pixels = 60

# Experiment handler saves experiment data automatically.
exp = data.ExperimentHandler(
    name = "cued_visual_search",
    version = '0.1',
    #extraInfo = settings,
    dataFileName = str(trials_data_folder / fileName),
    )
str(trials_data_folder / fileName)

# Define TrialHandler for managing trial-level data
trials = data.TrialHandler(
    nReps=1,  # Number of repetitions for the trial set
    method='random',  # Can also be 'random' for randomized trials
    trialList=None,  # If you have predefined trial conditions, you can specify them here
    name='trials'  # Name of the trial set
)

# Add the TrialHandler to the ExperimentHandler
exp.addLoop(trials)

# ==== Monitor & Display Settings ====
MONITOR_NAME = 'Iskra_monitor_204'
MONITOR = monitors.Monitor(MONITOR_NAME)

# Manually define monitor properties (important for custom environments)
MONITOR.setWidth(59.5)  # Monitor width in cm (adjust as needed)
MONITOR.setSizePix([2560, 1440])  # Screen resolution in pixels
MONITOR.setDistance(60)  # Distance from participant in cm

# Get screen size (returns None if the monitor is not correctly set)
SCREEN_SIZE = MONITOR.getSizePix()

# Ensure SCREEN_WIDTH and SCREEN_HEIGHT are properly set
if SCREEN_SIZE is None:
    SCREEN_WIDTH, SCREEN_HEIGHT = 2560, 1440  # Default resolution
else:
    SCREEN_WIDTH, SCREEN_HEIGHT = SCREEN_SIZE

print(f"Monitor: {MONITOR_NAME}, Resolution: {SCREEN_WIDTH}x{SCREEN_HEIGHT}")

# ==== Window Setup ====
win = visual.Window(
    size=[SCREEN_WIDTH, SCREEN_HEIGHT],
    color=background_color_rgb,
    fullscr=True,
    monitor=MONITOR_NAME,  
    screen=PRESENTATION_SCREEN,
    units='pix'
)

refresh_rate = win.monitorFramePeriod #get monitor refresh rate in seconds
print('monitor refresh rate: ' + str(round(refresh_rate, 3)) + ' seconds')

# SETUP EYETRACKING:
# Output gazeposition is alwys centered, i.e. screen center = [0,0].
if testmode_et:
    logging.info(' TESTMODE = TRUE')
    print('mouse is used to mimick eyetracker...')
    iohub_config = {'eyetracker.hw.mouse.EyeTracker': {'name': 'tracker'}}
if not testmode_et:
    logging.info('TESTMODE = FALSE')
    # Search for eye tracker:
    found_eyetrackers = tr.find_all_eyetrackers()
    my_eyetracker = found_eyetrackers[0]
    print("Address: " + my_eyetracker.address)
    logging.info(' ADDRESS: ' f'{my_eyetracker.address}')
    print("Model: " + my_eyetracker.model)
    logging.info(' Model: ' f'{my_eyetracker.model}')
    print("Name (It's OK if this is empty): " + my_eyetracker.device_name)
    logging.info(' Name (It is OK if this is empty): ' f'{my_eyetracker.device_name}')
    print("Serial number: " + my_eyetracker.serial_number)
    logging.info(' Serial number: ' f'{my_eyetracker.serial_number}')
    # Define a config that allow iohub to connect to the eye-tracker:
    iohub_config = {'eyetracker.hw.tobii.EyeTracker':
        {'name': 'tracker', 'runtime_settings': {'sampling_rate': sampling_rate, }}}
    
# IOHUB creates a different instance that records eye tracking data in hdf5 file saved in datastore_name:
io = launchHubServer(**iohub_config,
                        experiment_code = str(eyetracking_data_folder),
                        session_code = fileName,
                        datastore_name = str(eyetracking_data_folder / fileName), #where data is stored
                        window = win)

# Call the eyetracker device and start recording - different instance:
tracker = io.devices.tracker
tracker.setRecordingState(True)
print(tracker)

# Draw figure for gaze contincency, when gaze is offset:
def draw_gazedirect(background_color = background_color_rgb):
        # Adapt background according to provided "background color"
    if background_color is not background_color_rgb:
        background_rect = visual.Rect(
            win = win,
            size = win.size,
            fillColor = background_color)
        background_rect.draw()
    # Parameters:
    function_color = 'red'
    arrow_size_pix = size_fixation_cross_in_pixels
    arrow_pos_offset = 5
    width = 3

    rect1 = visual.Rect(
        win = win,
        units = 'pix',
        lineColor = function_color,
        fillColor = background_color,
        lineWidth = width,
        size = size_fixation_cross_in_pixels*6)

    # Arrow left:
    al_line1 = visual.Line(win = win, units = 'pix', lineColor=function_color, lineWidth=width)
    al_line1.start = [-(arrow_size_pix*arrow_pos_offset), 0]
    al_line1.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    al_line2 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth=width)
    al_line2.start = [-(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), -arrow_size_pix/2]
    al_line2.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    al_line3 = visual.Line(win = win, units = 'pix', lineColor=function_color, lineWidth=width)
    al_line3.start = [-(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), +arrow_size_pix/2]
    al_line3.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]

    # Arrow right:
    ar_line1 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    ar_line1.start = [+(arrow_size_pix*arrow_pos_offset), 0]
    ar_line1.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    ar_line2 = visual.Line(win = win, units='pix', lineColor = function_color, lineWidth = width)
    ar_line2.start = [+(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), -arrow_size_pix/2]
    ar_line2.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    ar_line3 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    ar_line3.start = [+(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), +arrow_size_pix/2]
    ar_line3.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]

    # Arrow top:
    at_line1 = visual.Line(win = win, units='pix', lineColor = function_color, lineWidth = width)
    at_line1.start = [0, +(arrow_size_pix*arrow_pos_offset)]
    at_line1.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    at_line2 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    at_line2.start = [-arrow_size_pix/2, +(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    at_line2.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    at_line3 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    at_line3.start = [+arrow_size_pix/2, +(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    at_line3.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]

    # Arrow bottom:
    ab_line1 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth=width)
    ab_line1.start = [0, -(arrow_size_pix*arrow_pos_offset)]
    ab_line1.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    ab_line2 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    ab_line2.start = [+arrow_size_pix/2, -(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    ab_line2.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    ab_line3 = visual.Line(win = win, units = 'pix', lineColor = function_color, lineWidth = width)
    ab_line3.start = [-arrow_size_pix/2, -(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    ab_line3.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]

    # Draw all:
    al_line1.draw()
    al_line2.draw()
    al_line3.draw()

    ar_line1.draw()
    ar_line2.draw()
    ar_line3.draw()

    at_line1.draw()
    at_line2.draw()
    at_line3.draw()

    ab_line1.draw()
    ab_line2.draw()
    ab_line3.draw()

    rect1.draw()

def check_nodata(gaze_position):
    if gaze_position == None:
        nodata_boolean = True
    else:
        nodata_boolean = False
    return nodata_boolean


# Get gaze position and offset cutoff.
gaze_offset_cutoff = 200
# Then check for the offset of gaze from the center screen.
def check_gaze_offset(gaze_position):
    gaze_center_offset = numpy.sqrt((gaze_position[0])**2 + (gaze_position[1])**2) #pythagoras theorem
    if gaze_center_offset >= gaze_offset_cutoff:
        offset_boolean = True
    else:
        offset_boolean = False
    return offset_boolean



# SETUP KEYBORD
kb = keyboard.Keyboard()

# Check for keypresses, used to pause and quit experiment:
def check_keypress():
    global current_screen
    keys = kb.getKeys(['p','escape'], waitRelease = True)
    timestamp_keypress = clock.getTime()

    if 'escape' in keys:
        current_screen = DIALOG_SCREEN
        dlg = gui.Dlg(title='Quit?', labelButtonOK=' OK ', labelButtonCancel=' Cancel ')
        dlg.addText('Do you really want to quit? - Then press OK')
        dlg.screen = 1 
        ok_data = dlg.show()  # show dialog and wait for OK or Cancel
        if dlg.OK:  # or if ok_data is not None
            print('EXPERIMENT ABORTED!')
            core.quit()
        else:
            print('Experiment continues...')
            current_screen = PRESENTATION_SCREEN
        pause_time = clock.getTime() - timestamp_keypress
    elif 'p' in keys:
        current_screen = DIALOG_SCREEN
        dlg = gui.Dlg(title='Pause', labelButtonOK='Continue')
        dlg.addText('Experiment is paused - Press Continue, when ready')
        dlg.screen = 1 
        ok_data = dlg.show()  # show dialog and wait for OK
        pause_time = clock.getTime() - timestamp_keypress
        print(f"Paused for {pause_time:.3f} seconds")
        current_screen = PRESENTATION_SCREEN 
    else:
        pause_time = 0
    pause_time = round(pause_time,3)
    return pause_time


def oddball_gazecontingent(oddball_object, duration_in_seconds, background_color=background_color_rgb):
    """
    Displays an oddball stimulus gaze-contingently.
    
    Args:
        oddball_object: An instance of the oddball class that handles stimulus drawing.
        duration_in_seconds: Duration for which the oddball is displayed (in seconds).
        background_color: Background color of the screen.
    """
    # Translate duration to number of frames:
    number_of_frames = round(duration_in_seconds / refresh_rate)
    timestamp = core.getTime()
    gaze_offset_duration = 0
    pause_duration = 0
    nodata_duration = 0
    
    # Oddball presentation for the specified duration:
    for frameN in range(number_of_frames):
        # Check for keypress:
        pause_duration += check_keypress()
        # Check for eye tracking data, only call once per flip:
        gaze_position = tracker.getPosition()
        # Check for eye tracking data:
        if check_nodata(gaze_position):
            print('warning: no eyes detected')
            logging.warning(' NO EYES DETECTED')
            frameN = 1  # reset duration of for loop - restart stimulus
            
            nodata_current_duration = 0
            while check_nodata(gaze_position):
                nodata_current_duration
                win.flip()  # Wait for monitor refresh time
                nodata_duration += refresh_rate
                nodata_current_duration += refresh_rate
                gaze_position = tracker.getPosition()  # Get new gaze data
        
        # Check for gaze offset:
        elif check_gaze_offset(gaze_position):
            print('warning: gaze offset')
            frameN = 1  # Reset duration of for loop - restart stimulus
            
            while not check_nodata(gaze_position) and check_gaze_offset(gaze_position):
                # Listen for keypress:
                pause_duration += check_keypress()
                draw_gazedirect(background_color)  # Redirect attention to stimulus area
                win.flip()  # Wait for monitor refresh time
                gaze_offset_duration += refresh_rate
                gaze_position = tracker.getPosition()  # Get new gaze data
        
        # Draw oddball stimulus:
        oddball_object.draw()  # Render the oddball on the screen
        win.flip()

    # Generate output info:
    actual_oddball_duration = round(core.getTime() - timestamp, 3)
    gaze_offset_duration = round(gaze_offset_duration, 3)
    nodata_duration = round(nodata_duration, 3)
    
    print('Number of frames: ' + str(number_of_frames))
    logging.info(' NUMBER OF FRAMES: ' f'{number_of_frames}')
    print('No data duration: ' + str(nodata_duration))
    logging.info(' NO DATA DURATION: ' f'{nodata_duration}')
    print('Gaze offset duration: ' + str(gaze_offset_duration))
    logging.info(' GAZE OFFSET DURATION: ' f'{gaze_offset_duration}')
    print('Pause duration: ' + str(pause_duration))
    logging.info(' PAUSE DURATION: ' f'{pause_duration}')
    print('Actual oddball duration: ' + str(actual_oddball_duration))
    logging.info(' ACTUAL ODDBALL DURATION: ' f'{actual_oddball_duration}')
    
    return [actual_oddball_duration, gaze_offset_duration, pause_duration, nodata_duration]

# Define circle positions 
circle_positions = [
    (0, 400),  # Top
    (400, 0),  # Right
    (0, -400), # Bottom
    (-400, 0)  # Left
]


# Create circle stimuli
circles = [visual.Circle(win, radius=100, fillColor=None, lineColor=None, pos=pos) for pos in circle_positions]


# ==== Fixation Cross for Baseline
fixation = visual.ShapeStim(
    win=win,
    vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
    lineWidth=3,
    closeShape=False,
    lineColor="black"
    )

FIXATION_TIME = 5 # 5 seconds

# Create a beep sound
beep = sound.Sound(value="A", secs=0.2)

# Number of trials
num_trials = 30


# Randomly, when i have more animations
animation_files = [f"media/videos/1080p60/{i}.mp4" for i in range(1, 18)]

# Set frame duration based on 60Hz refresh rate
frame_duration = 1.0/60.0  # 16.67ms per frame


# Initialize a trial counter 
trial_counter = 0

# --- PHASE 0: Baseline Fixation Cross (Only Once Before Trials Start) ---

trials = data.TrialHandler(trialList=None, method='sequential', nReps=1, extraInfo=exp_info)
exp.addLoop(trials)

fixation_start = time.time()

actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = oddball_gazecontingent(
    fixation, FIXATION_TIME, background_color=background_color_rgb
)
fixation_end = time.time()
fixation_duration = round(fixation_end - fixation_start, 3)

# Save fixation baseline data separately
exp.addData('baseline_fixation_start_timestamp', fixation_start)
exp.addData('baseline_fixation_end_timestamp', fixation_end)
exp.addData('baseline_fixation_duration', fixation_duration)
exp.addData('baseline_fixation_actual_isi_duration', actual_fixation_duration)
exp.addData('baseline_fixation_gaze_offset_duration', gaze_offset_fixation)
exp.addData('baseline_fixation_pause_duration', pause_fixation)
exp.addData('baseline_fixation_nodata_duration', nodata_fixation)

exp.nextEntry()  # Move to next row in data file

# Trial loop
for trial in range(num_trials):
    pause_duration= 0
    nodata_visual_search = 0
    print(f"Starting trial {trial + 1}")

    trial_start_time = time.time()
    trials = data.TrialHandler(trialList=None, method='sequential', nReps=1, extraInfo=exp_info)
    exp.addLoop(trials)

    # --- PHASE 1: Play Fixation Animation (Start of Trial) ---
    print(f"Trial {trial + 1}: Loading animation")
    start_time =core.getTime()

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

        print(f"Trial {trial + 1}: Starting animation")

        animation_start_time = core.getTime()
        animation_timeout = 2.0  # Max 2 seconds
        #fixation_animation.play()

        actual_anim_duration, gaze_offset_anim_duration, pause_anim_duration, nodata_anim_duration = oddball_gazecontingent(
            fixation_animation, 2.0, background_color_rgb
        )

        if fixation_animation.status != visual.FINISHED:
             print(f"Trial {trial + 1}: Animation player not initialized")
        
        animation_duration= core.getTime() - animation_start_time
        print(f"Trial {trial + 1}: Animation loop completed in {animation_duration:.3f} seconds")
        
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

    # Multiple screen clears before the next phase
    for _ in range(3):
        win.flip()

    # --- PHASE 2: Beep Phase ---
    print(f"Trial {trial + 1}: Starting beep phase")
    beep_phase_start_time = core.getTime()

    nodata_beep_interval = 0  # Track no data during beep
    beep_duration = 0

    auditory_cue = random.random() < 0.5
    print(f"Trial {trial + 1}: Beep {'Played' if auditory_cue else 'Not Played'}")

    if auditory_cue:
        pause_cue_duration=0
        pause_cue_duration += check_keypress()
        delay_frames = int(random.uniform(0, 0.1) / frame_duration)
        beep_frames = int(random.uniform(0.2, 0.3) / frame_duration)
        total_frames = int(0.4 / frame_duration)
        remaining_frames = total_frames - (delay_frames + beep_frames)

        delay_duration = round(delay_frames * frame_duration, 3)

        expected_beep_duration = round(beep_frames * frame_duration,3)

        # Delay phase
        for frame in range(delay_frames):
            if check_nodata(tracker.getPosition()):
                nodata_beep_interval += frame_duration
            win.flip()

        # Play beep
        beep_start_time = core.getTime()
        beep_start_time_unix = time.time()
        next_flip = win.getFutureFlipTime(clock='ptb')
        beep.play(when=next_flip)
        for frame in range(beep_frames):
            if check_nodata(tracker.getPosition()):
                nodata_beep_interval += frame_duration
            win.flip()
        beep.stop()

        beep_duration= round(core.getTime() - beep_start_time, 3)

        # Remaining time after beep
        for frame in range(remaining_frames):
            if check_nodata(tracker.getPosition()):
                nodata_beep_interval += frame_duration
            win.flip()
    
    else:
        for frame in range(int(0.4 / frame_duration)):  # No beep - just wait 400ms
            if check_nodata(tracker.getPosition()):
                nodata_beep_interval += frame_duration
            win.flip()
        # No beep case - Set expected_beep_duration to 0 or None
        expected_beep_duration = 0
        delay_duration = 0
    
    beep_phase_duration = round(core.getTime() - beep_phase_start_time, 3)
    print(f"Trial {trial + 1}: No data during beep interval = {nodata_beep_interval:.3f} seconds")
    print(f"Trial {trial + 1}: Beep phase completed in {beep_phase_duration:.3f} seconds")
    print(f"Trial {trial + 1}: Beep duration = {beep_duration:.2f} seconds")

    # ---  PHASE 3: Visual Search (Target Stimulus) ---
    pause_visual_search_duration = 0
    pause_visual_search_duration += check_keypress()
    # Isoluminant colors for green, red, and yellow 
    # (RGB values would be green: (-1,1,-1), red: (1,-1,-1), yellow: (1,1,-1))
    isoluminant_colors = {
    "green": (0, 131, 0),
    "red": (255, 0, 0),
    "yellow": (86,86, 0)
}

    # Select base and odd colors using their names
    base_color_name = random.choice(list(isoluminant_colors.keys()))
    odd_color_name = random.choice([c for c in isoluminant_colors if c != base_color_name]) # Ensure odd color is different from base color
    
    # Get RGB values
    base_color = isoluminant_colors[base_color_name]
    odd_color = isoluminant_colors[odd_color_name]
    
    circle_colors = [base_color] * 4  # creates a list of 4 elements which are set to one base_color
    odd_index = random.randint(0, 3) # randomly chosen index of the 4 positions in the list of circles, which determines the position od the odd-colored ball
    circle_colors[odd_index] = odd_color # the index is replaced with the odd_color
    circle_position = circle_positions[odd_index]
    # Determine the direction based on the odd_index
    if odd_index == 0:
        direction = "Top"
    elif odd_index == 1:
        direction = "Right"
    elif odd_index == 2:
        direction = "Bottom"
    elif odd_index == 3:
        direction = "Left"

    # Print the direction for debugging
    print(f"Odd circle is placed at: {direction} ({circle_position})")
    
    # Set the positions and colors for the circles
    for i, (circle, color) in enumerate(zip(circles, circle_colors)):
        circle.fillColor = color
        if i == odd_index:
            circle.pos = circle_position  # Set position for the odd-colored circle
    # 

    #for circle, color in zip(circles, circle_colors):# loops through circles list and assigns a corresponding color from the circle_colors list
       # circle.fillColor = color

    print(f"Trial {trial + 1}: Displaying circles")

    visual_search_start_time = core.getTime()
    while core.getTime() - visual_search_start_time < 1.5:  # 1.5 seconds
        for circle in circles:
            circle.draw()

        if check_nodata(tracker.getPosition()):  # Check for no data
            nodata_visual_search += frame_duration

        win.flip()
    
    actual_stimulus_duration = round(core.getTime() - visual_search_start_time, 3)
    print(f"Trial {trial + 1}: No data during circles = {nodata_visual_search:.3f} seconds")
    print(f"Trial {trial + 1}: Visual search phase completed in {actual_stimulus_duration:.3f} seconds")

    # Ensure the screen is clear after circles
    win.flip()

    # ---  SAVE TRIAL DATA ---
    trial_end_time = time.time()
    trial_duration = trial_end_time - trial_start_time

    trials.addData('trial_start_timestamp', trial_start_time)
    trials.addData('trial_end_timestamp', trial_end_time)
    trials.addData('trial_number', trial + 1)
    trials.addData('base_color', base_color_name)
    trials.addData('target_color', odd_color_name)
    trials.addData('target_position_index', odd_index)
    trials.addData('target_position', direction)
    trials.addData('actual_isi_anim_duration', actual_anim_duration) # from gazecontingent function
    trials.addData('t_animation_duration', round(animation_duration, 3)) # from timestamp
    trials.addData('gaze_offset_isi_anim_duration', gaze_offset_anim_duration) # from gazecontingent function
    trials.addData('pause_anim_duration', pause_anim_duration) # from gazecontingent function
    trials.addData('nodata_anim_duration', nodata_anim_duration) # from gazecontingent function
    trials.addData('auditory_cue', auditory_cue)
    trials.addData('timestamp_beep', beep_start_time_unix)
    trials.addData('actual_beep_duration', beep_duration)
    trials.addData('expected_beep_duration', round(expected_beep_duration, 3))
    trials.addData('nodata_beep_interval', round(nodata_beep_interval, 3))
    trials.addData('actual_beep_phase_duration', beep_phase_duration)
    trials.addData('delay_beep_phase', delay_duration) # delay before beep, if beep is played
    trials.addData('actual_visual_search_duration', round(actual_stimulus_duration, 3)) # from timestamp
    trials.addData('nodata_visual_search', round(nodata_visual_search, 3)) # from check_nodata function
    trials.addData('trial_duration', round(trial_duration,3)) # from timestamp
    
    exp.nextEntry()

print("\nExperiment Completed")
print(f"Total duration: {core.getTime() - start_time:.3f} seconds")

# --- SAVE FINAL DATA & CLOSE ---
trials.saveAsWideText(fileName, sheetName='trials', appendFile=True)
exp.saveAsPickle(fileName)

win.close()
core.quit()
