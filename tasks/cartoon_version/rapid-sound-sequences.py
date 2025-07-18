from psychopy import visual, core, sound, event, prefs, monitors, gui, data, clock
from psychopy.hardware import keyboard
from psychopy.visual import MovieStim3 as MovieStim
from psychopy.iohub import launchHubServer
from psychopy.monitors import Monitor
import numpy as np
import numpy
import random
import psychtoolbox as ptb
import tobii_research as tr
# Library for managing paths
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os
import traceback
import json
import sys
#send trigger via LSL
from pylsl import StreamInfo, StreamOutlet

# Load the config file
with open("tasks/cartoon_version/config.json", "r") as file:
    config = json.load(file)

#audio configuration
prefs.hardware['audioLib'] = [config["constants"]["audio"]["Lib"]]
prefs.hardware['audioDevice'] = config["constants"]["audio"]["device"]
prefs.hardware['audioSampleRate'] = 48000

# Select the task (e.g., "rapid-sound-sequences")
task_name = "rapid-sound-sequences"
task_config = config["tasks"][task_name]
constants = config["constants"]

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path =  Path(task_config["logging"]["base_path"], task_config["logging"]["log_folder"]).resolve()
filename_rapid_sound_sequences = os.path.join(logging_path, formatted_datetime)

# Check if the directory exists
if not logging_path.exists():
    # If it doesn't exist, create it
    logging_path.mkdir(parents=True, exist_ok=True)
else:
    print(f"Directory {logging_path} already exists. Continuing to use it.")

logging.basicConfig(
    level = logging.DEBUG,
    filename = filename_rapid_sound_sequences,
    filemode = 'w', # w = write, for each subject an separate log file.
    format = '%(asctime)s:%(levelname)s:%(name)s:%(message)s')

trials_data_folder = Path(task_config["data_paths"]["trials"]).resolve()
eyetracking_data_folder = Path(task_config["data_paths"]["eyetracking"]).resolve()

if not trials_data_folder.exists():
    trials_data_folder.mkdir(parents=True, exist_ok = True)
    
if not eyetracking_data_folder.exists():
    eyetracking_data_folder.mkdir(parents=True)

print(f"THIS IS {task_name.upper()}")
logging.info(f"THIS IS {task_name.upper()}")

participant_id = sys.argv[1]
timepoint = sys.argv[2]
print(f"Participant ID: {participant_id}, Timepoint: {timepoint}")

selected_timepoint = timepoint # Get the first item from the list

# Name for output data:
fileName =  f'{task_name}_{participant_id}_{selected_timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# Experiment handler saves experiment data automatically.
exp = data.ExperimentHandler(
    name = task_name,
    version = '0.2',
    dataFileName = str(trials_data_folder / fileName),
    )
str(trials_data_folder / fileName)

# Define TrialHandler for managing trial-level data
trials = data.TrialHandler(
    nReps=1,  # Number of repetitions for the trial set
    method='sequential',  # Can also be 'random' for randomized trials
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
    #print(f"DEBUG: gaze_position = {gaze_position}")
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
       
    return [actual_rss_duration, gaze_offset_duration, pause_duration, nodata_duration]


def cartoon_gazecontingent(anim_object, duration_in_seconds, background_color=background_color_rgb):
    """
    Displays an animation gaze-contingently, pausing when gaze is lost.
    
    Args:
        anim_object: A MovieStim object (the animation to play).
        duration_in_seconds: Total intended playback duration (excluding pauses).
        background_color: Background color of the screen.
    """
    # Get the animation frame rate (fps) from the MovieStim object
    # If not available, estimate using the refresh rate
    try:
        animation_fps = anim_object.frameRate
        if animation_fps is None or animation_fps <= 0:
            animation_fps = 1.0 / refresh_rate
    except AttributeError:
        animation_fps = 1.0 / refresh_rate
    
    # Calculate target duration in terms of frames
    target_frames = int(duration_in_seconds * animation_fps)
    
    # Start the animation
    anim_object.play()
    start_time = core.getTime()
    
    # Initialize tracking variables
    frames_played = 0
    gaze_offset_duration = 0
    pause_duration = 0
    nodata_duration = 0
    
    # Continue until we've played the requested number of frames
    while frames_played < target_frames:
        # Check for keypress (e.g., manual pause)
        pause_duration += check_keypress()
        
        # Get gaze position
        gaze_position = tracker.getPosition()
        
        # Case 1: No eyes detected (freeze animation)
        if check_nodata(gaze_position):
            print('warning: no eyes detected')
            logging.warning('NO EYES DETECTED')
            
            # Pause the animation
            anim_object.pause()
            
            # Handle the no-eyes-detected state
            nodata_start = core.getTime()
            while check_nodata(gaze_position):
                # Show blank screen
                win.flip()
                gaze_position = tracker.getPosition()
            
            nodata_duration += core.getTime() - nodata_start
            
            # Resume animation from where it was paused
            anim_object.play()
                
        # Case 2: Gaze offset (freeze animation)
        elif check_gaze_offset(gaze_position):
            print('warning: gaze offset')
            
            # Pause the animation
            anim_object.pause()
            
            # Handle the gaze-offset state
            gaze_offset_start = core.getTime()
            while (not check_nodata(gaze_position)) and check_gaze_offset(gaze_position):
                pause_duration += check_keypress()
                
                # Draw the gaze redirection cue (square)
                draw_gazedirect(background_color)
                win.flip()
                
                gaze_position = tracker.getPosition()
            
            gaze_offset_duration += core.getTime() - gaze_offset_start
            
            # Resume animation from where it was paused
            anim_object.play()
        
        # Normal playback
        else:
            # Draw the current frame of animation
            anim_object.draw()
            win.flip()
            
            # Only increment frames_played during normal playback
            frames_played += 1
    
    # Stop animation
    anim_object.stop()
    
    # Calculate total duration
    actual_duration = core.getTime() - start_time
    
    return [
        round(actual_duration, 3),
        round(gaze_offset_duration, 3),
        round(pause_duration, 3),
        round(nodata_duration, 3)
    ]

# EXPERIMENT SETTINGS
# Constants
DURATION_TONE = 0.05
POOL_SIZE = 20
MIN_FREQ = 200
MAX_FREQ = 2000
INTER_TRIAL_INTERVAL = 2
# Number of trials
#CONTROL_TRIALS = 5
#TRANSITION_TRIALS = 10
#TOTAL_TRIALS = 8 # Number of trials (not smaller than 8, default: 40)
CONTROL_TRIALS = 1 #repetitions of REG10 and RAND20
TRANSITION_TRIALS = 1 #repetitions of REG10-RAND20, REG00-REG1, RAND20-REG10

animation_files = [f"media/cartoons/{i}.mp4" for i in range(1, 40)]

# Generate frequency pool
frequency_pool = list(np.logspace(np.log10(MIN_FREQ), np.log10(MAX_FREQ), POOL_SIZE))

def generate_tone(frequency):
    return sound.Sound(value=frequency, secs=DURATION_TONE, stereo=True)

def play_tone_sequence(frequencies, num_repetitions, shuffle=False, name="", trial_num=0):
    """
    Play a sequence of tones for a specific number of repetitions and return the played sequences.
    """
    played_sequences = []  # Store the exact sequences as played
    sequence_duration = len(frequencies) * DURATION_TONE
    total_duration = sequence_duration * num_repetitions
    
    print(f"\n{name}")
    print(f"Sequence length: {len(frequencies)} tones")
    print(f"Single sequence duration: {sequence_duration}s")
    print(f"Number of repetitions: {num_repetitions}")
    print(f"Total expected duration: {total_duration}s")
    
    nodata_stimulus = 0
    gaze_offset_stimuli = 0

    # Get initial timing
    next_flip = win.getFutureFlipTime(clock='ptb')
    start_time = next_flip
    
    # Pre-generate all tones for all repetitions
    all_tones = []
    for rep in range(num_repetitions):
        current_frequencies = list(frequencies)  # Copy the sequence
        
        if shuffle:
            random.shuffle(current_frequencies)  # Shuffle if required
        
        played_sequences.append(current_frequencies[:])  # Store played order
        
        #print(f"\nRepetition {rep + 1}:")
        #print(f"Frequencies: {', '.join([f'{f:.1f}' for f in current_frequencies])}")
        
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
        if event.getKeys(['escape']):
            # Stop all scheduled tones
            for tone, _ in all_tones:
                tone.stop()
            return nodata_stimulus, gaze_offset_stimuli, played_sequences  # Return played sequences along with stimuli data
        
        # Check gaze position and update display accordingly
        gaze_position = tracker.getPosition()  # Get the current gaze position
        
        # Check for missing data (gaze position is None)
        if check_nodata(gaze_position):
            nodata_stimulus += refresh_rate  # Accumulate missing data time
            print("Warning: no eyes detected")
            fixation.draw()  # Show fixation during no data
        else:
            if gaze_position is not None:  # Ensure gaze_position is valid before checking offset
                if check_gaze_offset(gaze_position):
                    gaze_offset_stimuli += refresh_rate  # Accumulate gaze offset time
                    print("Warning: gaze offset")
                    draw_gazedirect(background_color_rgb)  # Show gaze direction when offset
                else:
                    fixation.draw()  # Show fixation when gaze is centered
            else:
                # If gaze_position is None, skip gaze offset handling and just show fixation
                print("Warning: Gaze position is None, skipping gaze offset check.")
                fixation.draw()  # Show fixation by default when gaze position is None
    
        win.flip()  # Update display with the current fixation status

    return nodata_stimulus, gaze_offset_stimuli, played_sequences  # Return exact played sequences

def generate_sequence(frequency_pool, tone_count, with_replacement=False):
    if with_replacement:
        return random.choices(frequency_pool, k=tone_count)
    else:
        return random.sample(frequency_pool, k=tone_count)
    
def generate_reg1_repeated_tone(frequency, tone_duration=0.05, total_duration=3.0, sample_rate=prefs.hardware['audioSampleRate']):
    samples_per_tone = int(tone_duration * sample_rate)
    num_repeats = int(total_duration / tone_duration)

    # Time vector for 50 ms
    t = np.linspace(0, tone_duration, samples_per_tone, False)
    tone_wave = 0.5 * np.sin(2 * np.pi * frequency * t)

    # === Fade in/out to reduce clicks ===
    fade_duration = 0.005  # 5ms fade in/out
    fade_samples = int(fade_duration * sample_rate)

    fade_in = np.linspace(0, 1, fade_samples)
    fade_out = np.linspace(1, 0, fade_samples)
    envelope = np.ones_like(tone_wave)
    envelope[:fade_samples] *= fade_in
    envelope[-fade_samples:] *= fade_out

    tone_wave *= envelope

    # Repeat tone burst
    full_wave = np.tile(tone_wave, num_repeats)

    return full_wave

def present_trial(condition, frequency_pool, trial_num):
    """Present a trial of the specified condition."""
    start_timestamp_0 = None
    transition_timestamp_1 = None
    end_timestamp_2 = None
    nodata_stimulus = 0
    gaze_offset_stimuli = 0
    reg1_tone_value = None
    all_played_sequences = []  # Use a separate list to keep track of all sequences

    # Ensure played_sequences is initialized properly for each condition
    played_sequences = []

    if condition == "REG10":
        start_timestamp_0 = core.getTime()
        # REG10: 10 tones sequence repeated 12 times (6 seconds)
        sequence = generate_sequence(frequency_pool, 10, with_replacement=False)
        for _ in range(12):  # REG10 repeats 12 times
            played_sequences.extend(sequence)
        result = play_tone_sequence(sequence, 12, shuffle=False, name="REG10", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, played_sequences = result
        else:
            # Handle error: not enough values returned, set default values or raise error
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        end_timestamp_2 = core.getTime()

    elif condition == "RAND20":
        start_timestamp_0 = core.getTime()
        # RAND20: 20 tones sequence repeated 6 times (6 seconds)
        sequence = generate_sequence(frequency_pool, 20, with_replacement=True)
        for _ in range(6):  # RAND20 repeats 6 times
            played_sequences.extend(sequence)
        result = play_tone_sequence(sequence, 6, shuffle=True, name="RAND20", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, played_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        end_timestamp_2 = core.getTime()

    elif condition == "REG10-RAND20":
        start_timestamp_0 = core.getTime()
        # First 3 seconds: REG10 (6 repetitions)
        sequence1 = generate_sequence(frequency_pool, 10, with_replacement=False)
        part1_sequences = []  # Store REG10 sequences separately
        for _ in range(6):  
            part1_sequences.extend(sequence1)
        result = play_tone_sequence(sequence1, 6, shuffle=False, name="REG10-RAND20 (REG10 part)", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, part1_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        # Capture timestamp at transition
        transition_timestamp_1 = core.getTime()

        # Second 3 seconds: RAND20 (3 repetitions)
        sequence2 = generate_sequence(frequency_pool, 20, with_replacement=True)
        part2_sequences = []  # Store RAND20 sequences separately
        for _ in range(3):  
            part2_sequences.extend(sequence2)
        result = play_tone_sequence(sequence2, 3, shuffle=True, name="REG10-RAND20 (RAND20 part)", trial_num=trial_num)

        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, part2_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        # Combine the two parts
        played_sequences.extend(part1_sequences)
        played_sequences.extend(part2_sequences)

        # Capture timestamp at end of second sequence (RAND20 part)
        end_timestamp_2 = core.getTime()

    elif condition == "RAND20-REG10":
        start_timestamp_0 = core.getTime()
        # First 3 seconds: RAND20 (3 repetitions)
        sequence1 = generate_sequence(frequency_pool, 20, with_replacement=True)
        part1_sequences = []  # Store RAND20 sequences separately
        for _ in range(3):  
            part1_sequences.extend(sequence1)
        result = play_tone_sequence(sequence1, 3, shuffle=True, name="RAND20-REG10 (RAND20 part)", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, part1_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        # Capture timestamp at transition
        transition_timestamp_1 = core.getTime()

        # Second 3 seconds: REG10 (6 repetitions)
        sequence2 = generate_sequence(frequency_pool, 10, with_replacement=False)
        part2_sequences = []  # Store REG10 sequences separately
        for _ in range(6):  
            part2_sequences.extend(sequence2)
        result = play_tone_sequence(sequence2, 6, shuffle=False, name="RAND20-REG10 (REG10 part)", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, part2_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        # Combine the two parts
        played_sequences.extend(part1_sequences)
        played_sequences.extend(part2_sequences)
        
        # Capture timestamp at end of second sequence (REG10 part)
        end_timestamp_2 = core.getTime()

    elif condition == "RAND20-REG1":
        start_timestamp_0 = core.getTime()  # Timestamp at the start
        
        # First 3 seconds: RAND20 (3 repetitions)
        sequence1 = generate_sequence(frequency_pool, 20, with_replacement=True)
        part1_sequences = []
        for _ in range(3):  
            part1_sequences.extend(sequence1)  # Extend the sequence with repetitions
        
        # Play RAND20 sequence (first part)
        result = play_tone_sequence(sequence1, 3, shuffle=True, name="RAND20-REG1 (RAND20 part)", trial_num=trial_num)
        
        # Check if we received three values, and unpack them
        if len(result) == 3:
            nodata_stimulus, gaze_offset_stimuli, part1_sequences = result
        else:
            print(f"Error: play_tone_sequence did not return the expected 3 values. Received: {len(result)} values.")
            return None  # Or handle error more appropriately
        
        # Capture timestamp at transition between RAND20 and REG1
        transition_timestamp_1 = core.getTime()
        
        # Generate reg1_tone (single tone for the second part of the trial)
        reg1_freq = random.choice(frequency_pool)  # Pick a tone from the pool
        reg1_tone_value = reg1_freq
        waveform = generate_reg1_repeated_tone(reg1_freq)
        
        # Instead of using play_tone_sequence, directly play the single tone for 3 seconds
        print(f"Trial Order Number {trial_num} - RAND20-REG1 (REG1 part)")
        print(f"Playing single tone: {reg1_tone_value} for 3.0s")

        # Play the full waveform as one seamless sound
        reg1_frames = int(3 / refresh_rate)
        reg1_tone = sound.Sound(value=waveform, sampleRate=prefs.hardware['audioSampleRate'], stereo=True)
        next_flip = win.getFutureFlipTime(clock='ptb')  # If syncing with screen
        reg1_tone.play(when=next_flip)
        
        # Wait for the full duration (3 seconds)
        for frame in range(reg1_frames):
            if event.getKeys(['escape']):
                reg1_tone.stop()
                break
            
            # Check gaze position and update display accordingly
            gaze_position = tracker.getPosition()
            
            if check_nodata(gaze_position):
                nodata_stimulus += refresh_rate
                print('warning: no eyes detected')
                fixation.draw()
            else:
                if gaze_position is not None:
                    if check_gaze_offset(gaze_position):
                        gaze_offset_stimuli += refresh_rate
                        print('warning: gaze offset')
                        draw_gazedirect(background_color_rgb)
                    else:
                        fixation.draw()
                else:
                    fixation.draw()
            
            win.flip()
        
        reg1_tone.stop()  # Ensure tone is stopped
        
        # Create part2_sequences for consistency
        part2_sequences = [reg1_tone_value] * int(3 / DURATION_TONE)
        
        # Combine the two parts
        played_sequences = part1_sequences + part2_sequences
        
        # Capture timestamp at end of second sequence (REG1 part)
        end_timestamp_2 = core.getTime()

    # Now save all sequences at the end of the trial (to prevent overwriting)
    all_played_sequences.append(played_sequences)
    # Helping debugging
    # print(f"reg1_tone: {reg1_tone_value}, type: {type(reg1_tone_value)}")
    # print(f"played_sequences: {played_sequences}, type: {type(played_sequences)}")

    return start_timestamp_0, transition_timestamp_1, end_timestamp_2, nodata_stimulus, gaze_offset_stimuli, played_sequences, reg1_tone_value or 0

# ==== Fixation Cross for Baseline
fixation = visual.ShapeStim(
    win=win,
    vertices=((0, -size_fixation_cross_in_pixels/2), 
              (0, size_fixation_cross_in_pixels/2), 
              (0, 0), 
              (-size_fixation_cross_in_pixels/2, 0), 
              (size_fixation_cross_in_pixels/2, 0)),
    #lineWidth=3,
    closeShape=False,
    lineColor="black"
    )

FIXATION_TIME = 5 # 5 seconds

# --- PHASE 0: Baseline Fixation Cross (Only Once Before Trials Start) ---
def show_baseline_fixation():
    print("\n===Starting Baseline Fixation Phase===")
    timestamp_exp =core.getTime()
    fixation_start = timestamp_exp
    trials = data.TrialHandler(trialList=None, method='sequential', nReps=1)
    exp.addLoop(trials)

    #send LSL trigger
    send_trigger([str(1), 'baseline', str(timestamp_exp)])

    #present baseline fixation cross for FIXATION_TIME seconds
    actual_fixation_duration, gaze_offset_fixation, pause_fixation, nodata_fixation = rapidsequences_gazecontingent(
        fixation, FIXATION_TIME, background_color=background_color_rgb
    )
    fixation_end = core.getTime()
    fixation_duration = round(fixation_end - fixation_start, 3)
    
    print(f"Expected Fixation Duration:{FIXATION_TIME}")
    print(f"Actual Fixation Duration: {actual_fixation_duration}")

    # Save fixation baseline data separately
    exp.addData('timestamp_exp',timestamp_exp)
    exp.addData('baseline_fixation_start_timestamp', fixation_start)
    exp.addData('baseline_fixation_end_timestamp', fixation_end)
    exp.addData('baseline_fixation_duration', fixation_duration)
    exp.addData('baseline_fixation_actual_isi_duration', actual_fixation_duration)
    exp.addData('baseline_fixation_gaze_offset_duration', gaze_offset_fixation)
    exp.addData('baseline_fixation_pause_duration', pause_fixation)
    exp.addData('baseline_fixation_nodata_duration', nodata_fixation)

    exp.nextEntry()  # Move to next row in data file

# A trial contains fixation cross, followed by a sequence of tones
def run_experiment():
    pause_duration= 0
    trial_number = 0
     
    # Define expected durations (for the sake of clarity)
    expected_durations = {
        "REG10": 10 * 0.05 * 12,  # 10 tones * 0.05 * 12 repetitions
        "RAND20": 20 * 0.05 * 6,  # 20 tones * 0.05 * 6 repetitions
        "REG10-RAND20": (10 * 0.05 * 6) + (20 * 0.05 * 3),  # 6s REG10 + 3s RAND20
        "RAND20-REG10": (20 * 0.05 * 3) + (10 * 0.05 * 6),  # 3s RAND20 + 6s REG10
        "RAND20-REG1": (20 * 0.05 * 3) + 3.0  # 3s RAND20 + 3s REG1
    }


    trial_order = [
        {"condition": "REG10", "trial_num": i, "expected_duration": expected_durations["REG10"]} for i in range(CONTROL_TRIALS)
    ] + [
        {"condition": "RAND20", "trial_num": i, "expected_duration": expected_durations["RAND20"]} for i in range(CONTROL_TRIALS)
    ] + [
        {"condition": "REG10-RAND20", "trial_num": i, "expected_duration": expected_durations["REG10-RAND20"]} for i in range(TRANSITION_TRIALS)
    ] + [
        {"condition": "RAND20-REG10", "trial_num": i, "expected_duration": expected_durations["RAND20-REG10"]} for i in range(TRANSITION_TRIALS)
    ] + [
        {"condition": "RAND20-REG1", "trial_num": i, "expected_duration": expected_durations["RAND20-REG1"]} for i in range(TRANSITION_TRIALS)
    ]

    random.shuffle(trial_order)  # Shuffle all trials to ensure randomness

    print("STARTING EXPERIMENT")
    start_time = core.getTime()

    #send LSL trigger
    send_trigger(['start', 'rapid sound sequences', str(start_time)])

    
    # **Start Eye-tracking Recording**,
    tracker.setRecordingState(True)  
    print("Eye-tracking recording started")

    # --- Phase 0: Show Baseline Fixation Cross before trials ---
    show_baseline_fixation()

    trials = data.TrialHandler(trialList=trial_order, method='sequential', nReps=1)
    exp.addLoop(trials)

    try:
        for trial_number, trial in enumerate(trials):
            
            condition = trial["condition"]
            trial_num = trial["trial_num"]
            expected_duration = trial['expected_duration']
            
            timestamp_exp =core.getTime()
            trial_start_time = timestamp_exp

            print(f"\n=== Trial {trial_number+1}: {condition} ===")
            try:
                # --- PHASE 1: Play Fixation Animation (Start of Trial) ---
                print(f"Trial {trial_number + 1}: Loading cartoon")
                cartoon_timeout = 2

                actual_cartoon_duration = 0
                gaze_offset_cartoon_duration = 0
                pause_cartoon_duration = 0
                nodata_cartoon_duration = 0
                try:
                    fixation_animation = visual.MovieStim(
                        win=win,
                        filename=random.choice(animation_files),
                        loop=False,
                        noAudio=True
                    )

                    video_width, video_height = 1920, 1080

                    target_width = size_fixation_cross_in_pixels * 6  # 360 pixels

                    # Calculate the scaling factor to maintain the aspect ratio
                    scale_factor = target_width / video_width

                    # Adjust video size based on scale factor
                    scaled_width = target_width
                    scaled_height = video_height * scale_factor
  
                    # Set the position to center the video and ensure the original size
                    fixation_animation.pos = (0, 0)
                    fixation_animation.size = (scaled_width, scaled_height)

                    print(f"Trial {trial_number + 1}: Starting animation")

                    cartoon_start_time = core.getTime()

                    #send LSL trigger
                    send_trigger([str(trial_number + 1), 'cartoon', str(cartoon_start_time)])

                    #cartoon presentation
                    actual_cartoon_duration, gaze_offset_cartoon_duration, pause_cartoon_duration, nodata_cartoon_duration = cartoon_gazecontingent(
                        fixation_animation, cartoon_timeout, background_color_rgb
                    )
                    
                    total_cartoon_duration= core.getTime() - cartoon_start_time
                    print(f"Trial {trial_number + 1}: Animation target duration: {cartoon_timeout:.3f} sec")
                    print(f"Trial {trial_number + 1}: Animation playback duration: {actual_cartoon_duration:.3f} sec")
                    print(f"Trial {trial_number + 1}: Total elapsed time (including pauses): {total_cartoon_duration:.3f} sec")
                    
                    # Log pause information if any occurred
                    if gaze_offset_cartoon_duration > 0 or nodata_cartoon_duration > 0:
                        print(f"Trial {trial_number + 1}: Gaze offset duration: {gaze_offset_cartoon_duration:.3f} sec")
                        print(f"Trial {trial_number + 1}: No eyes detected duration: {nodata_cartoon_duration:.3f} sec")

                    # Ensure animation is stopped
                    fixation_animation.stop()
                    del fixation_animation

                except Exception as e:
                    print(f"Trial {trial_number + 1}: Animation error: {e}")
                
                # Clear the screen with 3 blank frames
                for _ in range(3):
                    win.flip()
                    

                # --- Stimulus Phase ---
                print(f"\n---Starting Stimulus Trial {trial_number+1}, {condition}---")

                stimulus_start_time = core.getTime()  # Record start time of the stimulus

                #send LSL trigger
                send_trigger([str(trial_number + 1), condition, str(stimulus_start_time)])

                # Present the trial based on the condition
                start_timestamp_0, transition_timestamp_1, end_timestamp_2, nodata_stimulus, gaze_offset_stimuli, played_sequences, reg1_tone = present_trial(condition, frequency_pool, trial_num)
                                
                stimulus_end_time = core.getTime()  # Record end time of the stimulus
                stimulus_duration = round(stimulus_end_time - stimulus_start_time, 3)
                
                pause_duration += check_keypress()
                
                # Convert played sequences to string format for saving
                num_repetitions = len(played_sequences)

                if condition == "RAND20-REG1":
                    # For RAND20-REG1, separate RAND20 sequences and REG1 tone
                    # The first 3 elements are the RAND20 sequences
                    rand20_sequences = played_sequences[:3]
                    
                    # The last element is the REG1 tone
                    reg1_tone = played_sequences[-1]
                    
                    # Convert RAND20 sequences to strings
                    sequence_strings = []
                    for seq in rand20_sequences:
                        # Convert each sequence to a comma-separated string of frequencies
                        seq_string = ", ".join(f"{freq:.1f}" for freq in seq)
                        sequence_strings.append(seq_string)
                    
                    # Pad sequence_strings to maintain 12 columns
                    while len(sequence_strings) < 12:
                        sequence_strings.append("NA")
                
                else:
                    # Existing handling for other conditions
                    if played_sequences and len(played_sequences) > 0:
                        sequence_strings = []
                        for seq in played_sequences:
                            # Convert each sequence to a comma-separated string of frequencies
                            seq_string = ", ".join(f"{freq:.1f}" for freq in seq)
                            sequence_strings.append(seq_string)
                        
                        # Pad sequence_strings to maintain 12 columns
                        while len(sequence_strings) < 12:
                            sequence_strings.append("NA")
                    else:
                        print(f"Warning: No sequences recorded for trial {trial_number+1}")
                        sequence_strings = ["NA"] * 12

            except Exception as e:
                print(f"Error during trial {trial_number+1}: {e}")
                traceback.print_exc()
                continue  # Skip to the next trial  
            
            # **Log Trial Data**
            trial_end_time = core.getTime()
            trial_duration = round(trial_end_time - trial_start_time, 3)
            
            trials.addData('timestamp_exp', timestamp_exp)
            trials.addData('trial_start_time', trial_start_time) # from the trial in run_experiment
            trials.addData('trial_end_time', trial_end_time) #  from the trial in run_experiment
            trials.addData("Trial Number", trial_number+1 ) # from the global trial_number
            trials.addData('start_timestamp_0', start_timestamp_0) # from the present_trial function
            trials.addData('transition_timestamp_1', transition_timestamp_1) # from the present_trial function
            trials.addData('end_timestamp_2', end_timestamp_2) # from the present_trial function
            trials.addData("Condition", condition) # from the trial
            trials.addData('expected_stimulus_duration', expected_duration) # from the constants
            trials.addData("Stimulus_Duration", stimulus_duration) # calculated within the trial
            trials.addData("nodata_stimulus", round(nodata_stimulus, 3))   # from check_nodata function, within the experiment loop
            trials.addData("pause_stimulus ", pause_duration) # pause during the trials
            trials.addData("gaze_offset_stimuli", round(gaze_offset_stimuli,3)) # from check_gaze_offset function, within the experiment loop
            trials.addData("Gaze_Offset_Cartoon_Duration", gaze_offset_cartoon_duration)   # from gazecontingent function
            trials.addData("nodata_cartoon_Duration", nodata_cartoon_duration) #from gazecontingent function
            trials.addData("Pause_cartoon_Duration", pause_cartoon_duration) # from gazecontingent function
            trials.addData("Trial_Duration", trial_duration) # calculated within the trial
            trials.addData('cartoon_start', cartoon_start_time)
            trials.addData("cartoon_actual_duration", actual_cartoon_duration) #   from gazecontingent function, containing fixcorss presentation, gaze_offset_duration, no_data_duration, pause_duration
            trials.addData("num_repetitions", num_repetitions) # the number of repetitions of the sequence in the trial
            
            
             # Modify data logging for RAND20-REG1
            if condition == "RAND20-REG1":
                # Save data with special handling for REG1
                trials.addData("REG1 Frequency", round(reg1_tone, 1))

           # Add frequency sequences to trial data (up to 12 repetitions)
            for i in range(12):
                col_name = f"rep_{i+1}"
                trials.addData(col_name, sequence_strings[i] if i < num_repetitions else "NA")

            print(f"\nTotal Stimulus Duration {trial_duration}")

            trial_number += 1
            exp.nextEntry()

        #send LSL trigger
        end_time = core.getTime()
        send_trigger(['end', 'rapid sound sequences', str(end_time)])

        print("\nExperiment Completed")
        print(f"Total duration: {end_time - start_time:.2f} seconds")

    except Exception as e:
        print(f"An error occurred: {e}")
        #traceback.print_exc()
    finally:
         # Save and close ExperimentHandler
        #trials.saveAsExcel(str(fileName), appendFile=True)
        #exp.saveAsPickle(str(fileName))

        win.close()
        core.quit()

if __name__ == "__main__":
    run_experiment()