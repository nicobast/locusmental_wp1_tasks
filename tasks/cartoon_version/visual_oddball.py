from psychopy import visual, core, data, event, gui, logging, monitors, clock
import random, numpy, time
import logging
import numpy as np
from pathlib import Path
from datetime import datetime
from psychopy.hardware import keyboard
import tobii_research as tr
from psychopy.iohub import launchHubServer
from psychopy.monitors import Monitor
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
import traceback
import json
import sys
import pandas as pd
#send trigger via LSL
from pylsl import StreamInfo, StreamOutlet


# Load the config file
with open("tasks/cartoon_version/config.json", "r") as file:
    config = json.load(file)

# Select the task
task_name = "visual-oddball"
task_config = config["tasks"][task_name]
constants = config["constants"]

# ==== Logging ====
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path =  Path(task_config["logging"]["base_path"], task_config["logging"]["log_folder"]).resolve()
filename_visual_oddball = os.path.join(logging_path, formatted_datetime)

# Check if the directory exists
if not logging_path.exists():
    # If it doesn't exist, create it
    logging_path.mkdir(parents=True, exist_ok=True)
else:
    print(f"Directory {logging_path} already exists. Continuing to use it.")

logging.basicConfig(
    level=logging.DEBUG,
    filename=filename_visual_oddball,
    filemode='w',  # w = write, for each subject a separate log file
    format='%(asctime)s:%(levelname)s:%(name)s:%(message)s')


trials_data_folder = Path(task_config["data_paths"]["trials"]).resolve()

if not trials_data_folder.exists():
    trials_data_folder.mkdir(parents=True, exist_ok=True)

eyetracking_data_folder = Path(task_config["data_paths"]["eyetracking"]).resolve()

if not eyetracking_data_folder.exists():
    eyetracking_data_folder.mkdir(parents=True)

print(f"THIS IS {task_name.upper()}")
logging.info(f"THIS IS {task_name.upper()}")

# Get participant ID and timepoint from command-line arguments
participant_id = sys.argv[1]
timepoint = sys.argv[2]
print(f"Participant ID: {participant_id}, Timepoint: {timepoint}")

selected_timepoint = timepoint  # Get the first item from the list

# Name for output data
fileName =  f'{task_name}_{participant_id}_{selected_timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# Experiment handler
exp = data.ExperimentHandler(
    name=task_name,
    version='0.2',
    dataFileName=str(trials_data_folder / fileName),
)

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
testmode_et = config["constants"]["eyetracker"]["testmode"]
print(f"Test Mode (testmode_et): {testmode_et}") 
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
if testmode_et:  # Use mouse in test mode
    print('Mouse is used to mimic eye tracker...')
    iohub_config = {'eyetracker.hw.mouse.EyeTracker': {'name': 'tracker'}}
else:  # Otherwise, initialize actual eye tracker
    logging.info('TESTMODE = FALSE')
    # Search for the eye tracker
    found_eyetrackers = tr.find_all_eyetrackers()
    if found_eyetrackers:
        my_eyetracker = found_eyetrackers[0]
        print("Address: " + my_eyetracker.address)
        logging.info(f'ADDRESS: {my_eyetracker.address}')
        print("Model: " + my_eyetracker.model)
        logging.info(f'Model: {my_eyetracker.model}')
        print("Name (It's OK if this is empty): " + my_eyetracker.device_name)
        logging.info(f'Name: {my_eyetracker.device_name}')
        print("Serial number: " + my_eyetracker.serial_number)
        logging.info(f'Serial number: {my_eyetracker.serial_number}')
        # Define a config that allows iohub to connect to the actual eye tracker:
        iohub_config = {'eyetracker.hw.tobii.EyeTracker':
                        {'name': 'tracker', 'runtime_settings': {'sampling_rate': sampling_rate}}}
    else:
        logging.error('No eye tracker found.')
        print('No eye tracker found!')
    
# IOHUB creates a different instance that records eye tracking data in hdf5 file saved in datastore_name:
io = launchHubServer(**iohub_config,
                        experiment_code = str(eyetracking_data_folder),
                        session_code = str(fileName),
                        datastore_name = str(eyetracking_data_folder / str(fileName)), #where data is stored
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
    """Return True if no gaze data is available."""
    return gaze_position is None


# Get gaze position and offset cutoff.
gaze_offset_cutoff = 3 * size_fixation_cross_in_pixels

def check_gaze_offset(gaze_position):
    """
    Check if gaze is outside the cutoff distance from center.
    Assumes gaze_position is not None.
    """
    gaze_center_offset = numpy.sqrt((gaze_position[0])**2 + (gaze_position[1])**2)  # Pythagoras theorem
    return gaze_center_offset >= gaze_offset_cutoff

# SETUP KEYBORD
kb = keyboard.Keyboard()

# Check for keypresses, used to pause and quit experiment:
def check_keypress():
    global current_screen
    keys = kb.getKeys(['p','escape'], clear = True)
    timestamp_keypress = clock.getTime()

    if 'escape' in keys:
        print("Escape key detected! Showing quit dialog.")  # Debugging
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
        pause_time =0
        pause_time = round(pause_time,3) if pause_time else 0
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
    gaze_offset_isi_duration = 0
    pause_isi_duration = 0
    nodata_isi_duration = 0
    
    # Oddball presentation for the specified duration:
    for frameN in range(number_of_frames):
        # Check for keypress:
        pause_isi_duration += check_keypress()
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
                nodata_isi_duration += refresh_rate
                nodata_current_duration += refresh_rate
                gaze_position = tracker.getPosition()  # Get new gaze data
        
        # Check for gaze offset:
        elif check_gaze_offset(gaze_position):
            print('warning: gaze offset')
            frameN = 1  # Reset duration of for loop - restart stimulus
            
            while not check_nodata(gaze_position) and check_gaze_offset(gaze_position):
                # Listen for keypress:
                pause_isi_duration += check_keypress()
                draw_gazedirect(background_color)  # Redirect attention to stimulus area
                win.flip()  # Wait for monitor refresh time
                gaze_offset_isi_duration += refresh_rate
                gaze_position = tracker.getPosition()  # Get new gaze data
        
        # Draw oddball stimulus:
        oddball_object.draw()  # Render the fixation cross on the screen
        win.flip()

    # Generate output info:
    actual_isi_duration = round(core.getTime() - timestamp, 3)
    gaze_offset_isi_duration = round(gaze_offset_isi_duration, 3)
    nodata_isi_duration = round(nodata_isi_duration, 3)
       
    return [actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration]


# ==== Stimulus Properties ====
STANDARD_SIZE = 130 # degrees 2.9
ODDBALL_SIZE = 209  # degrees 4.6
STIMULUS_COLOR = (0,.4,.6)

# ==== Timing (in seconds) ====
STIMULUS_DURATION = 150 / 1000  # 150ms
ISI_DURATION = 1500 / 1000  # 1500ms
FIXATION_TIME = 5  # 10s fixation cross

# ==== Trial Structure ====
TOTAL_TRIALS = 75 
#TOTAL_TRIALS = 10 # For testing purposes, set to 75 trials as default
STANDARD_RATIO = 0.8
ODDBALL_RATIO = 0.2

STANDARD_TRIALS = int(TOTAL_TRIALS * STANDARD_RATIO)
print(f"Standard trials: {STANDARD_TRIALS}")
#ODDBALL_TRIALS = int(TOTAL_TRIALS * ODDBALL_RATIO)
ODDBALL_TRIALS = TOTAL_TRIALS - STANDARD_TRIALS
print(f"Oddball trials: {ODDBALL_TRIALS}")

# ==== Stimulus Setup ====
standard = visual.Circle(win, radius=STANDARD_SIZE / 2, fillColor=STIMULUS_COLOR, lineColor=STIMULUS_COLOR)
oddball = visual.Circle(win, radius=ODDBALL_SIZE / 2, fillColor=STIMULUS_COLOR, lineColor=STIMULUS_COLOR)

# ==== Fixation Cross Function ====

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

def create_trial_sequence():
    """
    Creates a trial sequence using two basic patterns:
    1. standard_pair: ['standard', 'standard']
    2. oddball_sequence: ['standard', 'standard', 'oddball']
    """
    # Define our basic sequences
    standard_pair = ['standard', 'standard']
    oddball_sequence = ['standard', 'standard', 'oddball']
    
    # Calculate how many oddball sequences we need
    num_oddball_sequences = ODDBALL_TRIALS
    
    # Calculate remaining standards after accounting for standards in oddball sequences
    remaining_standard_pairs = (STANDARD_TRIALS - (num_oddball_sequences * 2)) // 2
    
    # Build the sequence
    sequence = []
    
    # Add oddball sequences randomly spaced with standard pairs
    all_subsequences = (
        [oddball_sequence] * num_oddball_sequences + 
        [standard_pair] * remaining_standard_pairs
    )
    random.shuffle(all_subsequences)
    
    # Flatten the sequence
    for subsequence in all_subsequences:
        sequence.extend(subsequence)
    
    # Verify sequence length and composition
    print(f"Total trials: {len(sequence)}")
    print(f"Standards: {sequence.count('standard')}")
    print(f"Oddballs: {sequence.count('oddball')}")
    
    return sequence

# ==== Single Trial Function (Stimulus → ISI) ====
def run_trial(trial_type):
    nodata_stimulus = 0
    logging.info(f'Running trial type: {trial_type}')
    timestamp_exp = core.getTime()
    trial_start_time = timestamp_exp

    # === 1. Show the stimulus first ===
    stimulus = standard if trial_type == 'standard' else oddball

    stimulus_frames = int(STIMULUS_DURATION / refresh_rate)
    stimulus_start = core.getTime()

    for _ in range(stimulus_frames):
        stimulus.draw()

        if check_nodata(tracker.getPosition()):
            nodata_stimulus += refresh_rate
            print ('warning: no eyes detected')
        elif check_gaze_offset(tracker.getPosition()):
            print('warning: gaze offset')

        win.flip()

    stimulus_end = core.getTime()
    stimulus_duration = round(stimulus_end - stimulus_start, 3)

    # === 2. Show blank screen for ISI AFTER stimulus ===
    blank_screen = visual.Rect(
        win=win,
        width=2,
        height=2,
        fillColor=background_color_rgb,
        units='norm'
    )
    ISI_start = core.getTime()
    # Gaze-contingent function during ISI
    actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration = oddball_gazecontingent(
        blank_screen, ISI_DURATION, background_color=background_color_rgb
    )
    ISI_end = core.getTime()
    ISI_duration_timestamp =  round(ISI_end -ISI_start, 3)
    trial_end_time = core.getTime()
    trial_duration = round(trial_end_time - trial_start_time, 3)

    return timestamp_exp, stimulus_start, stimulus_end, stimulus_duration, nodata_stimulus, trial_duration, actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration, ISI_duration_timestamp, ISI_start, ISI_end


# ==== Main Experiment Function ====
def run_experiment():
    trial_counter = 0
    baseline_trial_counter = 0

    logging.info('Starting experiment')
    start_time = core.getTime()

    #send LSL trigger
    send_trigger(['start', 'visual oddball', str(start_time)])
    
    trial_sequence = ['baseline_fixation'] + create_trial_sequence()
    trials = data.TrialHandler(
        nReps=1,
        method='sequential',
        trialList=[{'condition': trial_type} for trial_type in trial_sequence],
        
    )
    
    exp.addLoop(trials)

    try:
        # Fixation Phase First
        for thisTrial in trials:
            trial_type = thisTrial['condition']
            
            if trial_type == 'baseline_fixation':
                timestamp_exp = core.getTime()
                baseline_fixation_start = core.getTime()
                
                #send LSL trigger
                send_trigger([str(baseline_trial_counter), trial_type, str(timestamp_exp)])

                # Draw the fixation cross for the baseline fixation
                actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = oddball_gazecontingent(
                    fixation, FIXATION_TIME, background_color=background_color_rgb
                )
                
                baseline_fixation_end = core.getTime()
                baseline_fixation_duration = round(baseline_fixation_end - baseline_fixation_start, 3)
                
                trials.addData('baseline_trial_number', baseline_trial_counter+1)  
                #trials.addData('condition', 'baseline_fixation')
                trials.addData('timestamp_exp', timestamp_exp)
                trials.addData('expected_baseline_fixation_duration', FIXATION_TIME)
                trials.addData('baseline_fixation_duration', baseline_fixation_duration)
                trials.addData('baseline_fixation_actual_duration', actual_fixation_duration)
                trials.addData('baseline_fixation_gaze_offset_duration', gaze_offset_fixation)
                trials.addData('baseline_fixation_pause_duration', pause_fixation)
                trials.addData('baseline_fixation_nodata_duration', nodata_fixation)

                # Print relevant information for baseline fixation
                print(f"\nBaseline Fixation Phase ")
                print(f"Expected Duration: {FIXATION_TIME} seconds")
                print(f"Duration from timestamp: {baseline_fixation_duration} seconds")
                print(f'Duration from function: {actual_fixation_duration}')
                print(f"Gaze Offset Duration: {gaze_offset_fixation}")
                print(f"Pause Duration: {pause_fixation}")
                print(f"No Data Duration: {nodata_fixation}")
                
                baseline_trial_counter += 1  # Increment after each trial
                exp.nextEntry()
                continue

            # Stimulus trials (standard/oddball)
            trial_start = core.getTime()

            #send LSL trigger
            send_trigger([str(trial_counter+1), trial_type, str(trial_start)])

            # Run the trial using only run_trial function
            timestamp_exp, stimulus_start, stimulus_end, stimulus_duration, nodata_stimulus, trial_duration, actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration, ISI_duration_timestamp, ISI_start, ISI_end = run_trial(trial_type)

            # Save trial data
            trials.addData('trial_number', trial_counter +1)  # Ensuring unique numbering
            trials.addData('timestamp_exp', timestamp_exp)
            trials.addData('stimulus_start_timestamp', stimulus_start)
            trials.addData('stimulus_end_timestamp', stimulus_end)
            trials.addData('stimulus_duration', stimulus_duration)
            trials.addData('nodata_stimulus', round(nodata_stimulus,3))
            trials.addData('trial_duration', trial_duration)
            trials.addData('ISI_start_timestamp', ISI_start)
            trials.addData('ISI_end_timestamp', ISI_end)
            trials.addData('expected_isi_duration', ISI_DURATION)
            trials.addData('ISI_duration_timestamp',ISI_duration_timestamp)
            trials.addData('gaze_offset_isi_duration', gaze_offset_isi_duration)
            trials.addData('pause_isi_duration', pause_isi_duration)
            trials.addData('nodata_isi_duration', nodata_isi_duration)
            trials.addData('actual_isi_duration', actual_isi_duration) # from gazecontingency function

            # Print relevant information for the current stimulus trial
            print(f"\n-----Trial {trial_counter+1}-----")
            print(f"Trial Type: {trial_type.capitalize()}")
            print(f"Stimulus Duration: {stimulus_duration} seconds")
            print(f"ISI Expected Duration: {ISI_DURATION} seconds")
            print(f'ISI Actual Duration: {actual_isi_duration}')
            print(f"Gaze Offset Duration: {gaze_offset_isi_duration}")
            print(f"Pause Duration: {pause_isi_duration}")
            print(f"No Data Duration: {nodata_isi_duration}")
            print(f"Trial Duration: {trial_duration} seconds")

            trial_counter += 1  # Increment after each trial
            exp.nextEntry()

            print(f"Trial duration timestamp: {core.getTime() - trial_start:.3f} seconds")

        print("\nAdding final fixation baseline...")
        timestamp_exp = core.getTime()
        fixation_start = core.getTime()
        
        #send LSL trigger
        send_trigger([str(baseline_trial_counter), 'baseline_fixation', str(timestamp_exp)])

        #final baseline presentation
        actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = oddball_gazecontingent(
            fixation, FIXATION_TIME, background_color=background_color_rgb
        )
        
        fixation_end = core.getTime()
        fixation_duration = round(fixation_end - fixation_start, 3)
        
        trials.addData('condition', 'final_baseline_fixation')
        trials.addData('timestamp_exp', timestamp_exp)
        trials.addData('expected_baseline_fixation_duration', FIXATION_TIME)
        trials.addData('baseline_fixation_duration', fixation_duration)
        trials.addData('baseline_fixation_actual_duration', actual_fixation_duration)
        trials.addData('baseline_fixation_gaze_offset_duration', gaze_offset_fixation)
        trials.addData('baseline_fixation_pause_duration', pause_fixation)
        trials.addData('baseline_fixation_nodata_duration', nodata_fixation)
        
         # Print relevant information for final fixation
        print(f"\nFinal Baseline Fixation")
        print(f"Expected Duration: {FIXATION_TIME} seconds")
        print(f"Actual Duration: {fixation_duration} seconds")
        print(f"Gaze Offset Duration: {gaze_offset_fixation}")
        print(f"Pause Duration: {pause_fixation}")
        print(f"No Data Duration: {nodata_fixation}")
        logging.info(f"Final Baseline Fixation completed")

        exp.nextEntry()
  
        print("\nExperiment Completed")
        end_time = core.getTime()
        print(f"Total task duration: {end_time - start_time:.3f} seconds")

        #send LSL trigger
        send_trigger(['end', 'visual oddball', str(end_time)])

    finally:
        print ("Saving data...")
        # print("Column names before saving:", trials.data.keys())      
        exp.saveAsWideText(str(trials_data_folder / fileName))
        exp.saveAsPickle(str(trials_data_folder / fileName))
        # except Exception as e:
       # print(f"Error while saving:{e}")

    # Close reading from eyetracker:
    tracker.setRecordingState(False)
    # Close iohub instance:
    io.quit()

    win.close()
    core.quit()


# Start the experiment
if __name__ == '__main__':
    run_experiment()