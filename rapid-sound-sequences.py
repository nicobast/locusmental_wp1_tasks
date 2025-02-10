from psychopy import visual, core, sound, event, prefs, monitors, gui, data, clock
from psychopy.hardware import keyboard
from psychopy.iohub import launchHubServer
import numpy as np
import numpy
import random
import time
import psychtoolbox as ptb
import tobii_research as tr
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
import traceback

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path( "data", "rapid-sound-sequences", "logging_data").resolve()
filename_rapid_sound_sequences = os.path.join(logging_path, formatted_datetime)

logging.basicConfig(
    level = logging.DEBUG,
    filename = filename_rapid_sound_sequences,
    filemode = 'w', # w = write, for each subject an separate log file.
    format = '%(asctime)s:%(levelname)s:%(name)s:%(message)s')
    
print("THIS IS RAPID SOUND SEQUENCES")
logging.info('THIS IS RAPID SOUND SEQUENCES')

# Path to output data:
path_to_data = Path( "data", "rapid-sound-sequences").resolve()
trials_data_folder = Path(path_to_data, 'trialdata')
eyetracking_data_folder = Path(path_to_data, 'eyetracking')
loggings_data_folder = Path(path_to_data, 'logging_data')

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
    title= "Rapid Sound Sequences",
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
fileName = f'rapid_sound_sequences{exp_info["Participant ID"]}_{timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
testmode_et = True
sampling_rate = 60 # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
background_color_rgb = "#666666"
size_fixation_cross_in_pixels = 60

# Experiment handler saves experiment data automatically.
exp = data.ExperimentHandler(
    name = "rapid-sound-sequences",
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

# Monitor and window setup remains the same...
mon = monitors.Monitor(
    name='Iskra_monitor_204',
    width=59.5,
    distance=60
)

prefs.hardware['audioLib'] = ['ptb']
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)'
prefs.hardware['audioLatencyMode'] = 3

# Initialize window and visual components
win = visual.Window(
    size=[2560, 1440],  # Set resolution to match monitor
    color="#666666",
    units="pix"
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
    keys = kb.getKeys(['p','escape'], waitRelease = True)
    timestamp_keypress = clock.getTime()

    if 'escape' in keys:
        dlg = gui.Dlg(title='Quit?', labelButtonOK=' OK ', labelButtonCancel=' Cancel ')
        dlg.addText('Do you really want to quit? - Then press OK')
        ok_data = dlg.show()  # show dialog and wait for OK or Cancel
        if dlg.OK:  # or if ok_data is not None
            print('EXPERIMENT ABORTED!')
            core.quit()
        else:
            print('Experiment continues...')
        pause_time = clock.getTime() - timestamp_keypress
    elif 'p' in keys:
        dlg = gui.Dlg(title='Pause', labelButtonOK='Continue')
        dlg.addText('Experiment is paused - Press Continue, when ready')
        ok_data = dlg.show()  # show dialog and wait for OK
        pause_time = clock.getTime() - timestamp_keypress
    else:
        pause_time = 0
    pause_time = round(pause_time,3)
    return pause_time


def rapidsequences_gazecontingent(rss_object, duration_in_seconds, background_color=background_color_rgb):
    """
    Displays a rss stimulus gaze-contingently.
    
    Args:
        rss_object: An instance of the rss class that handles stimulus drawing.
        duration_in_seconds: Duration for which the rss is displayed (in seconds).
        background_color: Background color of the screen.
    """
    # Translate duration to number of frames:
    number_of_frames = round(duration_in_seconds / refresh_rate)
    timestamp = core.getTime()
    gaze_offset_duration = 0
    pause_duration = 0
    nodata_duration = 0
    
    # rss presentation for the specified duration:
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
        
        # Draw rss stimulus:
        rss_object.draw()  
        win.flip()

    # Generate output info:
    actual_rss_duration = round(core.getTime() - timestamp, 3)
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
    print('Actual duration: ' + str(actual_rss_duration))
    logging.info(' ACTUAL RSS DURATION: ' f'{actual_rss_duration}')
    
    return [actual_rss_duration, gaze_offset_duration, pause_duration, nodata_duration]

# Constants
DURATION_TONE = 0.05
POOL_SIZE = 20
MIN_FREQ = 200
MAX_FREQ = 2000
CONTROL_TRIALS = 10
TRANSITION_TRIALS = 15
TOTAL_TRIALS = CONTROL_TRIALS * 2 + TRANSITION_TRIALS * 2
INTER_TRIAL_INTERVAL = 2
#REFRESH_RATE = 60

# Generate frequency pool
frequency_pool = list(np.logspace(np.log10(MIN_FREQ), np.log10(MAX_FREQ), POOL_SIZE))

# Create fixation cross
fixation = visual.ShapeStim(
    win=win,
    vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
    lineWidth=5,
    closeShape=False,
    lineColor="black"
)

def generate_tone(frequency):
    return sound.Sound(value=frequency, secs=DURATION_TONE, stereo=True)

def play_tone_sequence(frequencies, num_repetitions, shuffle=False, name="", trial_num=0):# trial_num is assigned dynamically in the experiment run later
    """
    Play a sequence of tones for a specific number of repetitions.
    """
    sequence_duration = len(frequencies) * DURATION_TONE
    total_duration = sequence_duration * num_repetitions
    
    print(f"\nTrial {trial_num} - {name}")
    print(f"Sequence length: {len(frequencies)} tones")
    print(f"Single sequence duration: {sequence_duration}s")
    print(f"Number of repetitions: {num_repetitions}")
    print(f"Total expected duration: {total_duration}s")
    
    # Get initial timing
    next_flip = win.getFutureFlipTime(clock='ptb')
    start_time = next_flip
    
    # Pre-generate all tones for all repetitions
    all_tones = []
    for rep in range(num_repetitions):
        current_frequencies = list(frequencies)
        if shuffle:
            random.shuffle(current_frequencies)
            
        print(f"\nRepetition {rep + 1}:")
        print(f"Frequencies: {', '.join([f'{f:.1f}' for f in current_frequencies])}")
        
        for idx, freq in enumerate(current_frequencies):
            tone = sound.Sound(value=freq, secs=DURATION_TONE, stereo=True)
            play_time = start_time + (rep * sequence_duration) + (idx * DURATION_TONE)
            all_tones.append((tone, play_time))
    
    # Schedule all tones at once
    for tone, play_time in all_tones:
        tone.play(when=play_time)
    
    # Draw fixation for the total duration
    total_frames = int(total_duration / refresh_rate)
    for frame in range(total_frames):
        fixation.draw()
        win.flip()
        
        if event.getKeys(['escape']):
            # Stop all scheduled tones
            for tone, _ in all_tones:
                tone.stop()
            return True
    
    # Ensure all tones are stopped
    for tone, _ in all_tones:
        tone.stop()
    
    return False

def generate_sequence(frequency_pool, tone_count, with_replacement=False):
    if with_replacement:
        return random.choices(frequency_pool, k=tone_count)
    else:
        return random.sample(frequency_pool, k=tone_count)

def present_trial(condition, frequency_pool, trial_num):
    """Present a trial of the specified condition."""
    if condition == "REG10":
        # REG10: 10 tones sequence repeated 12 times (6 seconds)
        sequence = generate_sequence(frequency_pool, 10, with_replacement=False)
        return play_tone_sequence(sequence, 12, shuffle=False, name="REG10", trial_num=trial_num)
    
    elif condition == "RAND20":
        # RAND20: 20 tones sequence repeated 6 times (6 seconds)
        sequence = generate_sequence(frequency_pool, 20, with_replacement=True)
        return play_tone_sequence(sequence, 6, shuffle=True, name="RAND20", trial_num=trial_num)
    
    elif condition == "REG10-RAND20":
        # First 3 seconds: REG10 (6 repetitions)
        sequence1 = generate_sequence(frequency_pool, 10, with_replacement=False)
        if play_tone_sequence(sequence1, 6, shuffle=False, name="REG10-RAND20 (REG10 part)", trial_num=trial_num):
            return True
        
        # Second 3 seconds: RAND20 (3 repetitions)
        sequence2 = generate_sequence(frequency_pool, 20, with_replacement=True)
        return play_tone_sequence(sequence2, 3, shuffle=True, name="REG10-RAND20 (RAND20 part)", trial_num=trial_num)
    
    elif condition == "RAND20-REG10":
        # First 3 seconds: RAND20 (3 repetitions)
        sequence1 = generate_sequence(frequency_pool, 20, with_replacement=True)
        if play_tone_sequence(sequence1, 3, shuffle=True, name="RAND20-REG10 (RAND20 part)", trial_num=trial_num):
            return True
        
        # Second 3 seconds: REG10 (6 repetitions)
        sequence2 = generate_sequence(frequency_pool, 10, with_replacement=False)
        return play_tone_sequence(sequence2, 6, shuffle=False, name="RAND20-REG10 (REG10 part)", trial_num=trial_num)

# A trial contains fixation cross, followed by a sequence of tones
def run_experiment():
    pause_duration= 0

    trial_order = [
        {"condition": "REG10", "trial_num": i} for i in range(CONTROL_TRIALS)
    ] + [
        {"condition": "RAND20", "trial_num": i} for i in range(CONTROL_TRIALS)
    ] + [
        {"condition": "REG10-RAND20", "trial_num": i} for i in range(TRANSITION_TRIALS)
    ] + [
        {"condition": "RAND20-REG10", "trial_num": i} for i in range(TRANSITION_TRIALS)
    ]

    random.shuffle(trial_order)  # Shuffle all trials to ensure randomness

    print("Starting Experiment")
    start_time = core.getTime()
    
    # **Start Eye-tracking Recording**,
    tracker.setRecordingState(True)  
    print("Eye-tracking recording started")

    trials = data.TrialHandler(trialList=trial_order, method='sequential', nReps=1, extraInfo=exp_info)
    exp.addLoop(trials)

    try:
        for trial in trials:
            condition = trial["condition"]
            trial_num = trial["trial_num"]

            trial_start_time = core.getTime()
            print(f"\n=== Trial {trial_num}: {condition} ===")
            try:
                # **ITI - Inter-Trial Interval**
                iti_frames = int(INTER_TRIAL_INTERVAL / refresh_rate)
                print(f"ITI Frames: {iti_frames}")  # Debugging: Print ITI frames
                isi_start_time = core.getTime() 
                for _ in range(iti_frames):
                    fixation.draw()
                    win.flip()
                
                actual_rss_duration, gaze_offset_duration, pause_duration, nodata_duration = rapidsequences_gazecontingent(
                rss_object=fixation,  
                duration_in_seconds=INTER_TRIAL_INTERVAL,  
                background_color = background_color_rgb   
                )
                
                isi_end_time = core.getTime()  # Get end time after ISI
                iti_actual_duration = round(isi_end_time - isi_start_time,3)
                print(f"Inter Stimulus Interval, Duration: {iti_actual_duration}")
                print(f"ISI Expected Duration: {INTER_TRIAL_INTERVAL}")

                print(f"Presenting trial {trial_num} with condition: {condition}")

                stimulus_start_time = core.getTime()  # Record start time of the stimulus
                present_trial(condition, frequency_pool, trial_num)
                stimulus_end_time = core.getTime()  # Record end time of the stimulus
                stimulus_duration = round(stimulus_end_time - stimulus_start_time, 3)
                
                pause_duration += check_keypress()

            except Exception as e:
                print(f"Error during trial {trial_num}: {e}")
                traceback.print_exc()
                continue  # Skip to the next trial  
            
            # **Log Trial Data**
            trial_end_time = core.getTime()
            trial_duration = round(trial_end_time - trial_start_time, 3)

            trials.addData('trial_start_time', trial_start_time) # from the trial
            trials.addData('trial_end_time', trial_end_time) #  from the trial
            trials.addData("Trial", trial_num) # from the trial, trial_order
            trials.addData("Condition", condition) # from the trial
            trials.addData("Stimulus_Duration", stimulus_duration) # calculated within the trial
            trials.addData("Gaze_Offset_Duration", gaze_offset_duration)   # from gazecontingent function
            trials.addData("No_Data_Duration", nodata_duration) #from gazecontingent function
            trials.addData("Pause_Duration", pause_duration) # from gazecontingent function
            trials.addData("Trial_Duration", trial_duration) # calculated within the trial
            trials.addData("ISI", INTER_TRIAL_INTERVAL) # from the constants
            trials.addData('ISI Actual Duration', iti_actual_duration) # calculated within the trial
            trials.addData("ISI_Duration", actual_rss_duration) #   from gazecontingent function, containing fixcorss presentation, gaze_offset_duration, no_data_duration, pause_duration

            exp.nextEntry()

        print("\nExperiment Completed")
        print(f"Total duration: {core.getTime() - start_time:.2f} seconds")

    except Exception as e:
        print(f"An error occurred: {e}")
        traceback.print_exc()
    finally:
         # Save and close ExperimentHandler
        trials.saveAsExcel(fileName, sheetName='trials', appendFile=True)
        exp.saveAsPickle(fileName)

        win.close()
        core.quit()

if __name__ == "__main__":
    run_experiment()