# Import necessary modules
from psychopy import prefs
from psychopy.hardware import keyboard
from psychopy import visual, core, sound, gui, data, clock
import tobii_research as tr
from psychopy.iohub import launchHubServer
from psychopy.monitors import Monitor
import random, numpy
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
from datetime import datetime
import json
import sys

#send trigger via LSL
from pylsl import StreamInfo, StreamOutlet

# Load the config file
with open("tasks/cartoon_version/config.json", "r") as file:
    config = json.load(file)

print("Available tasks:", config["tasks"].keys())  # Debugging step
# Select the task 
task_name = "cued-visual-search"
task_config = config["tasks"][task_name]
constants = config["constants"]

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path =  Path(task_config["logging"]["base_path"], task_config["logging"]["log_folder"]).resolve()
filename_visual_search = os.path.join(logging_path, formatted_datetime)

# Check if the directory exists
if not logging_path.exists():
    # If it doesn't exist, create it
    logging_path.mkdir(parents=True, exist_ok=True)
else:
    print(f"Directory {logging_path} already exists. Continuing to use it.")

logging.basicConfig(
    level = logging.DEBUG,
    filename = filename_visual_search,
    filemode = 'w', # w = write, for each subject an separate log file.
    format = '%(asctime)s:%(levelname)s:%(name)s:%(message)s')
    
trials_data_folder = Path(task_config["data_paths"]["trials"]).resolve()
eyetracking_data_folder = Path(task_config["data_paths"]["eyetracking"]).resolve()

if not trials_data_folder.exists():
    trials_data_folder.mkdir(parents=True)
    
if not eyetracking_data_folder.exists():
    eyetracking_data_folder.mkdir(parents=True)

# Get participant ID and timepoint from command-line arguments
participant_id = sys.argv[1]
timepoint = sys.argv[2]
print(f"Participant ID: {participant_id}, Timepoint: {timepoint}")

selected_timepoint = timepoint[0]  # Get the first item from the list
# Name for output data:
fileName = f'{task_name}_{participant_id}_{selected_timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# Experiment handler saves experiment data automatically.
exp = data.ExperimentHandler(
    name = task_name,
    version = '0.2',
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

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
testmode_et = config["constants"]["eyetracker"]["testmode"]
sampling_rate = config["constants"]["eyetracker"]["sampling_rate"] # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
background_color_rgb = config["constants"]["psychopy_window"]["background_color"]
size_fixation_cross_in_pixels = config["constants"]["psychopy_window"]["size_fixation_cross_in_pixels"]

#Create the LSL stream
info = StreamInfo(
    name='Markers',           # Stream name (must match what you select in LabRecorder)
    type='Markers',           # Stream type (must match in LabRecorder)
    channel_count=3,          # 1 for simple triggers
    nominal_srate=0,          # Irregular sampling rate for event markers
    channel_format='string',  # Markers are usually strings
    source_id='stimulus_stream'  # Unique ID for your experiment/session
)
outlet = StreamOutlet(info)

# Access values
audio_device = config["constants"]["audio"]["device"]
latency_mode = config["constants"]["audio"]["latency_mode"]
audio_lib = 'config["constants"]["audio"]["Lib"]'

# Set the audio library and device using prefs
prefs.hardware['audioLib'] = [audio_lib]  # Set audio library (e.g., 'ptb')
prefs.hardware['audioDevice'] = audio_device  # Set audio device

# Define screens
PRESENTATION_SCREEN = config["constants"]["presentation_screen"]
DIALOG_SCREEN = config["constants"]["dialog_screen"]
current_screen = PRESENTATION_SCREEN  # Start in presentation mode

MONITOR_NAME = config["constants"]["monitor"]["name"]

mon = Monitor(MONITOR_NAME)
mon.setWidth(config["constants"]["monitor"]["width_cm"])  # Physical width of the screen
mon.setDistance(config["constants"]["monitor"]["distance_cm"])  # Distance from participant
mon.setSizePix([config["constants"]["monitor"]["width"], config["constants"]["monitor"]["height"]])  # Screen resolution

win = visual.Window(
    size=(config["constants"]["monitor"]["width"], config["constants"]["monitor"]["height"]),
    fullscr=config["constants"]["psychopy_window"]["fullscreen"],
    screen=config["constants"]["presentation_screen"],
    color=config["constants"]["psychopy_window"]["background_color"],
    monitor=MONITOR_NAME,
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

#Send a trigger (marker) function
def send_trigger(marker):
    # marker must be a list of strings, length = channel_count
    outlet.push_sample(marker)

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
gaze_offset_cutoff = 3*size_fixation_cross_in_pixels
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
    vertices=((0, -size_fixation_cross_in_pixels/2), 
              (0, size_fixation_cross_in_pixels/2), 
              (0, 0), 
              (-size_fixation_cross_in_pixels/2, 0), 
              (size_fixation_cross_in_pixels/2, 0)),
    closeShape=False,
    lineColor="black"
    )

# EXPERIMENTAL SETTINGS
FIXATION_TIME = 5 # 5 seconds
INTER_TRIAL_INTERVAL = 1.5
# Create a beep sound
beep = sound.Sound(value="A", secs=0.2, volume=1)
# Number of trials
#num_trials = 30
num_trials = 5 # Set to 5 for testing, change to 30 for full experiment
# Initialize a trial counter 
trial_counter = 0

# --- PHASE 0: Baseline Fixation Cross (Only Once Before Trials Start) ---
def show_baseline_fixation():
    print("Displaying Baseline Fixation Cross for 5 seconds.")
    trials = data.TrialHandler(trialList=None, method='sequential', nReps=1)
    exp.addLoop(trials)

    timestamp_exp = core.getTime()
    fixation_start = timestamp_exp

    #send LSL trigger
    send_trigger([str(trial_counter), 'baseline', str(timestamp_exp)])

    #baseline presentation
    actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = oddball_gazecontingent(
        fixation, FIXATION_TIME, background_color=background_color_rgb
    )
    fixation_end = core.getTime()
    fixation_duration = round(fixation_end - fixation_start, 3)

    # Save fixation baseline data separately
    exp.addData('timestamp_exp', timestamp_exp)
    exp.addData('baseline_fixation_start_timestamp', fixation_start)
    exp.addData('baseline_fixation_end_timestamp', fixation_end)
    exp.addData('baseline_fixation_duration', fixation_duration)
    exp.addData('baseline_fixation_actual_isi_duration', actual_fixation_duration)
    exp.addData('baseline_fixation_gaze_offset_duration', gaze_offset_fixation)
    exp.addData('baseline_fixation_pause_duration', pause_fixation)
    exp.addData('baseline_fixation_nodata_duration', nodata_fixation)

    exp.nextEntry()  # Move to next row in data file

def run_experiment():

    print("Starting Experiment")
     # **Start Eye-tracking Recording**,
    tracker.setRecordingState(True)  
    print("Eye-tracking recording started")    

    start_time = core.getTime()

    #send LSL trigger
    send_trigger(['start', 'cued visual search', str(start_time)])
    
     # --- Phase 0: Show Baseline Fixation Cross before trials ---
    show_baseline_fixation()

    # Trial loop
    for trial in range(num_trials):
        pause_duration= 0
        nodata_visual_search = 0
        print(f"\n----TRIAL {trial + 1}----")

        timestamp_exp = core.getTime()
        trial_start_time = timestamp_exp
        trials = data.TrialHandler(trialList=None, method='sequential', nReps=1)
        exp.addLoop(trials)

        # --- PHASE 1: Play Inter Stimulus Interval (ISI)  ---
        # 
        isi_start_time = core.getTime()
        send_trigger([str(trial + 1), 'isi', str(isi_start_time)])  #send LSL trigger      
        actual_oddball_duration, gaze_offset_duration, pause_duration, nodata_duration = oddball_gazecontingent(
        oddball_object=fixation,  
        duration_in_seconds=INTER_TRIAL_INTERVAL,  
        background_color = background_color_rgb   
        )
                
        isi_end_time = core.getTime()  # Get end time after ISI
        isi_actual_duration = round(isi_end_time - isi_start_time,3)
        print(f"Inter Stimulus Interval, Duration: {isi_actual_duration}")
        print(f"ISI Expected Duration: {INTER_TRIAL_INTERVAL}")

        # --- PHASE 2: Beep Phase ---
        print(f"\nTrial {trial + 1}: Starting beep phase")
        beep_phase_start_time = core.getTime()

        nodata_beep_interval = 0  # Track no data during beep
        beep_duration = 0
        beep_start_time = 0
        beep_end_time = 0
        auditory_cue = random.random() < 0.5
        print(f"Trial {trial + 1}: Beep {'Played' if auditory_cue else 'Not Played'}")
        send_trigger([str(trial + 1), str(auditory_cue), str(beep_phase_start_time)])  #send LSL trigger      
        
        if auditory_cue:
            #beep = sound.Sound(value='A', secs=0.2) 
            pause_cue_duration=0
            pause_cue_duration += check_keypress()
            delay_frames = int(random.uniform(0, 0.1) / refresh_rate)
            beep_frames = int(random.uniform(0.2, 0.3) / refresh_rate)
            total_frames = int(0.4 / refresh_rate)
            remaining_frames = total_frames - (delay_frames + beep_frames)
            
            delay_duration = round(delay_frames * refresh_rate, 3)
            expected_beep_duration = round(beep_frames * refresh_rate,3)
            print(f"Trial {trial + 1}: Delay frames = {delay_frames} ({delay_duration} sec)")
            print(f"Trial {trial + 1}: Beep frames = {beep_frames} ({expected_beep_duration} sec)")
            print(f"Trial {trial + 1}: Remaining frames = {remaining_frames}")

            # Delay phase
            for frame in range(delay_frames):
                if check_nodata(tracker.getPosition()):
                    nodata_beep_interval += refresh_rate
                win.flip()

            # Play beep
            beep_start_time = core.getTime()
            
            next_flip = win.getFutureFlipTime(clock='ptb')
        
            beep.play(when=next_flip) 
                      
            print(f"Trial {trial + 1}: Beep STARTED at {beep_start_time}")
            for frame in range(beep_frames):
                if check_nodata(tracker.getPosition()):
                    nodata_beep_interval += refresh_rate
                win.flip()
            beep.stop()

            beep_end_time = core.getTime()
            beep_duration= round(beep_end_time - beep_start_time, 3)
            print(f"Trial {trial + 1}: Beep STOPPED, actual duration = {beep_duration} sec")

            # Remaining time after beep
            for frame in range(remaining_frames):
                if check_nodata(tracker.getPosition()):
                    nodata_beep_interval += refresh_rate
                win.flip()
        
        else:
            for frame in range(int(0.4 / refresh_rate)):  # No beep - just wait 400ms
                if check_nodata(tracker.getPosition()):
                    nodata_beep_interval += refresh_rate
                win.flip()
            # No beep case - Set expected_beep_duration to 0 or None
            expected_beep_duration = 0
            delay_duration = 0

        beep_phase_end_timestamp = core.getTime()
        beep_phase_duration = round(core.getTime() - beep_phase_start_time, 3)
        print(f"Trial {trial + 1}: No data during beep interval = {nodata_beep_interval:.3f} seconds")
        print(f"Trial {trial + 1}: Beep phase completed in {beep_phase_duration:.3f} seconds")
        print(f"Trial {trial + 1}: Beep duration = {beep_duration:.3f} seconds")

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
        print(f"Trial {trial + 1}: Target Position: {direction} ({circle_position})")
        
        # Set the positions and colors for the circles
        for i, (circle, color) in enumerate(zip(circles, circle_colors)):
            circle.fillColor = color
            if i == odd_index:
                circle.pos = circle_position  # Set position for the odd-colored circle
        
        print(f"Trial {trial + 1}: Displaying circles")

        visual_search_start_time = core.getTime()
        send_trigger([str(trial + 1), direction, str(visual_search_start_time)])  #send LSL trigger      
        
        while core.getTime() - visual_search_start_time < 1.5:  # 1.5 seconds
            for circle in circles:
                circle.draw()

            if check_nodata(tracker.getPosition()):  # Check for no data
                nodata_visual_search += refresh_rate
            win.flip()

        actual_stimulus_duration = round(core.getTime() - visual_search_start_time, 3)
        print(f"Trial {trial + 1}: No data during circles = {nodata_visual_search:.3f} seconds")
        print(f"Trial {trial + 1}: Visual search phase completed in {actual_stimulus_duration:.3f} seconds")
        

        # Ensure the screen is clear after circles
        win.flip()

        # ---  SAVE TRIAL DATA ---
        trial_end_time = core.getTime()
        trial_duration = trial_end_time - trial_start_time
        print(f'Trial {trial + 1} Duration: {trial_duration:.3f} seconds')

        trials.addData('timestamp_exp', timestamp_exp)
        trials.addData('trial_start_timestamp', trial_start_time)
        trials.addData('trial_end_timestamp', trial_end_time)
        trials.addData('trial_number', trial + 1)
        trials.addData('base_color', base_color_name)
        trials.addData('target_color', odd_color_name)
        trials.addData('target_position_index', odd_index)
        trials.addData('target_position', direction)
        trials.addData('ISI_start_timestamp', isi_start_time)
        trials.addData('ISI_end_timestamp',isi_end_time)
        trials.addData("ISI_Gaze_Offset_Duration", gaze_offset_duration)   # from gazecontingent function
        trials.addData("ISI_nodata_Duration", nodata_duration) #from gazecontingent function
        trials.addData("ISI_Pause_Duration", pause_duration) # from gazecontingent function
        trials.addData("Trial_Duration", trial_duration) # calculated within the trial
        trials.addData("ISI_expected", INTER_TRIAL_INTERVAL) # from the constants
        trials.addData('ISI_duration_timestamp', isi_actual_duration) # calculated within the trial
        trials.addData("ISI_actual_duration", actual_oddball_duration) # from gazecontingent function
        trials.addData('auditory_cue', auditory_cue)
        trials.addData('beep_phase_start_timestamp', beep_phase_start_time)
        trials.addData('beep_phase_end_timestamp', beep_phase_end_timestamp)
        trials.addData('beep_start_timestamp', beep_start_time)
        trials.addData('beep_end_timestamp', beep_end_time)
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
    end_time = core.getTime()
    print(f"Total duration: {(end_time - start_time)/60:.2f} minutes")

    #send LSL trigger
    send_trigger(['end', 'cued visual search', str(end_time)])

    # --- SAVE FINAL DATA & CLOSE ---
    #trials.saveAsWideText(fileName, sheetName='trials', appendFile=True)
    #exp.saveAsPickle(fileName)


    # Close reading from eyetracker:
    tracker.setRecordingState(False)
    # Close iohub instance:
    io.quit()

    win.close()
    core.quit()

if __name__ == "__main__":
    run_experiment()