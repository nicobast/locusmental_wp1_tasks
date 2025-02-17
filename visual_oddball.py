from psychopy import visual, core, data, event, gui, logging, monitors, clock
import random, numpy
import logging
import numpy as np
from pathlib import Path
import os
from datetime import datetime
from psychopy.hardware import keyboard
import tobii_research as tr
from psychopy.iohub import launchHubServer
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
import traceback


# Define screens
PRESENTATION_SCREEN = 0
DIALOG_SCREEN = 1
current_screen = PRESENTATION_SCREEN  # Start in presentation mode

# ==== Logging ====
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path("data", "visual_oddball", "logging_data").resolve()
filename_oddball = os.path.join(logging_path, formatted_datetime)

logging.basicConfig(
    level=logging.DEBUG,
    filename=filename_oddball,
    filemode='w',  # w = write, for each subject a separate log file
    format='%(asctime)s:%(levelname)s:%(name)s:%(message)s')

print("THIS IS VISUAL ODDBALL TASK.")
logging.info('THIS IS VISUAL ODDBALL TASK.')

# ==== Data Output ====
# Path to output data
path_to_data = Path("data", "visual_oddball").resolve()
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
    title="Visual Oddball Task",
    order=["Participant ID", "Timepoint"]
)
if not dlg.OK:
    logging.warning("Experiment canceled by the user.")
    core.quit()

participant_id = exp_info["Participant ID"]
timepoint = exp_info["Timepoint"][0]

logging.info(f"Participant ID: {participant_id}")
logging.info(f"Timepoint: {timepoint}")

# Name for output data
fileName = f'visual_oddball_{exp_info["Participant ID"]}_{timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
testmode_et = False
sampling_rate = 60 # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
background_color_rgb = "#666666"
size_fixation_cross_in_pixels = 60

# Experiment handler
exp = data.ExperimentHandler(
    name="visual_oddball",
    version='0.1',
    dataFileName=str(trials_data_folder / fileName),
)

# Define TrialHandler for managing trial-level data
trials = data.TrialHandler(
    nReps=1,  # Number of repetitions for the trial set
    method='sequential',  # Can also be 'random' for randomized trials
    trialList=None,  # If you have predefined trial conditions, you can specify them here
    name='trials'  # Name of the trial set
)

# Add the TrialHandler to the ExperimentHandler
exp.addLoop(trials)

# ==== Monitor & Display Settings ====
MONITOR_NAME = 'Iskra_monitor_204'
MONITOR = monitors.Monitor(MONITOR_NAME, distance=60)
SCREEN_WIDTH, SCREEN_HEIGHT = MONITOR.getSizePix()
BACKGROUND_COLOR = '#666666'
FULLSCREEN = True

# ==== Window Setup ====
win = visual.Window(
    size=[SCREEN_WIDTH, SCREEN_HEIGHT], 
    color=BACKGROUND_COLOR,
    fullscr=FULLSCREEN,
    monitor=MONITOR_NAME,
    screen=PRESENTATION_SCREEN,
    units='pix'
)


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

refresh_rate = win.monitorFramePeriod #get monitor refresh rate in seconds
print('monitor refresh rate: ' + str(round(refresh_rate, 3)) + ' seconds')

# Set frame duration based on 60Hz refresh rate
frame_duration = 1.0/60.0  # 16.67ms per frame

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
gaze_offset_cutoff = 600
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
    
    print('Number of frames: ' + str(number_of_frames))
    logging.info(' NUMBER OF FRAMES: ' f'{number_of_frames}')
    print('No data duration: ' + str(nodata_isi_duration))
    logging.info(' NO DATA DURATION: ' f'{nodata_isi_duration}')
    print('Gaze offset duration: ' + str(gaze_offset_isi_duration))
    logging.info(' GAZE OFFSET DURATION: ' f'{gaze_offset_isi_duration}')
    print('Pause duration: ' + str(pause_isi_duration))
    logging.info(' PAUSE DURATION: ' f'{pause_isi_duration}')
    print('Actual oddball duration: ' + str(actual_isi_duration))
    logging.info(' ACTUAL ODDBALL DURATION: ' f'{actual_isi_duration}')
    
    return [actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration]


# ==== Stimulus Properties ====
STANDARD_SIZE = 114 # degrees 2.9
ODDBALL_SIZE = 180  # degrees 4.6
STIMULUS_COLOR = 'blue'

# ==== Timing (in seconds) ====
STIMULUS_DURATION = 150 / 1000  # 150ms
ISI_DURATION = 1500 / 1000  # 1500ms
FIXATION_TIME = 10  # 10s fixation cross

# ==== Trial Structure ====
TOTAL_TRIALS = 30 # adjust to 110 for real experiment
STANDARD_RATIO = 0.77
ODDBALL_RATIO = 0.23

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
    vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
    lineWidth=3,
    closeShape=False,
    lineColor="black"
    )

def show_fixation():
    
    iti_frames = int(FIXATION_TIME/ refresh_rate) # duration measured in frames
    print(f"ITI Frames: {iti_frames}")  
    for _ in range(iti_frames):
        fixation.draw()
        win.flip()


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

# ==== Single Trial Function ====
def run_trial(trial_type):
    nodata_stimulus = 0
    logging.info(f'Running trial type: {trial_type}')
    
    stimulus = standard if trial_type == 'standard' else oddball
    trial_start_time = core.getTime()

    # Calculate total number of frames for stimulus duration
    stimulus_frames = int(STIMULUS_DURATION / refresh_rate)  # e.g., 60 Hz → 6 frames for 100ms
    stimulus_start = core.getTime()

    for _ in range(stimulus_frames):
        stimulus.draw()
        
        # Track missing gaze data (if applicable)
        if check_nodata(tracker.getPosition()):  
            nodata_stimulus += frame_duration  # Accumulate missing data time
        
        win.flip()  # Flip the window each frame to show the stimulus

    stimulus_end = core.getTime()
    stimulus_duration = round(stimulus_end - stimulus_start, 3)

    # Show blank screen for ISI (Inter-Stimulus Interval)
    blank_screen = visual.Rect(
        win=win,
        width=2,
        height=2,
        fillColor=background_color_rgb,
        units='norm'
    )
    
    # Call the gaze-contingent function during ISI and pass the blank screen and ISI duration
    actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration = oddball_gazecontingent(
        blank_screen, ISI_DURATION, background_color=background_color_rgb
    )

    trial_end_time = core.getTime()
    trial_duration = round(trial_end_time - trial_start_time, 3)

    return stimulus_duration, nodata_stimulus, trial_duration, actual_isi_duration,gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration

# ==== Main Experiment Function ====
def run_experiment():
    logging.info('Starting experiment')
    
    trial_sequence = ['fixation'] + create_trial_sequence()
    trials = data.TrialHandler(
        nReps=1,
        method='sequential',
        trialList=[{'condition': trial_type} for trial_type in trial_sequence],
        dataTypes=[
            'trial_number',
            'condition',
            'stimulus_duration',
            'actual_isi_duration',
            'gaze_offset_isi_duration',
            'pause_isi_duration',
            'nodata_isi_duration',
            'trial_duration',
            'fixation_duration',
            'fixation_actual_isi_duration',
            'fixation_gaze_offset_duration',
            'fixation_pause_duration',
            'fixation_nodata_duration'
        ]
    )
    
    exp.addLoop(trials)

    try:
        # Fixation Phase First
        for thisTrial in trials:
            trial_type = thisTrial['condition']
            
            if trial_type == 'fixation':
                fixation_start = core.getTime()
                
                actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = oddball_gazecontingent(
                    fixation, FIXATION_TIME, background_color=background_color_rgb
                )
                
                fixation_end = core.getTime()
                fixation_duration = round(fixation_end - fixation_start, 3)
                
                trials.addData('trial_number', trials.thisN + 1)
                trials.addData('condition', 'fixation')
                trials.addData('fixation_duration', fixation_duration)
                trials.addData('fixation_actual_isi_duration', actual_fixation_duration)
                trials.addData('fixation_gaze_offset_duration', gaze_offset_fixation)
                trials.addData('fixation_pause_duration', pause_fixation)
                trials.addData('fixation_nodata_duration', nodata_fixation)
                
                exp.nextEntry()
                continue

            # Stimulus trials (standard/oddball)
            trial_start = core.getTime()

            # Run the trial using only run_trial function
            stimulus_duration, nodata_stimulus, trial_duration, actual_isi_duration, gaze_offset_isi_duration, pause_isi_duration, nodata_isi_duration = run_trial(trial_type)

            # Save trial data
            trials.addData('trial_number', trials.thisN)
            trials.addData('condition', trial_type)
            trials.addData('stimulus_duration', stimulus_duration)
            trials.addData('nodata_stimulus', nodata_stimulus)
            trials.addData('trial_duration', trial_duration)
            trials.addData('gaze_offset_isi_duration', gaze_offset_isi_duration)
            trials.addData('pause_isi_duration', pause_isi_duration)
            trials.addData('nodata_isi_duration', nodata_isi_duration)
            trials.addData('actual_isi_duration', actual_isi_duration)

            exp.nextEntry()

        print("\nExperiment Completed")
        print(f"Total duration: {core.getTime() - trial_start:.2f} seconds")

    except Exception as e:
        print(f"An error occurred: {e}")
        traceback.print_exc()
    finally:
        trials.saveAsWideText(fileName, appendFile=True)
        exp.saveAsPickle(fileName)
        logging.info('Experiment completed')
        win.close()
        core.quit()

# Start the experiment
if __name__ == '__main__':
    run_experiment()