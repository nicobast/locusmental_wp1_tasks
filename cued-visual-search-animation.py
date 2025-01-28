# Import necessary modules
from psychopy import prefs
prefs.hardware['audioLib'] = ['ptb'] # PTB described as highest accuracy sound class
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)' # define audio device - DEVICE SPECIFIC
prefs.hardware['audioLatencyMode'] = 3 # high sound priority, low latency mode
prefs.general['audioSampleRate'] = 44100
from psychopy.hardware import keyboard
from psychopy import visual, core, event, sound, monitors, gui, data, iohub, clock
import tobii_research as tr
from psychopy.iohub import launchHubServer
import random, numpy
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
testmode_et = False
sampling_rate = 60 # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
background_color_rgb = "#666666"
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

# Create a beep sound
beep = sound.Sound(value="A", secs=0.2)

# Number of trials
num_trials = 30


# Randomly, when i have more animations
animation_files = [f"media/videos/1080p60/{i}.mp4" for i in range(1, 21)]

# Set frame duration based on 60Hz refresh rate
frame_duration = 1.0/60.0  # 16.67ms per frame


# Initialize a trial counter 
trial_counter = 0

# Trial loop
for trial in range(num_trials):
    print(f"Starting trial {trial + 1}")
    
    stimulus_start_time = core.getTime()  # Record the start time

    # Present circles for 1.5 seconds (90 frames at 60Hz)
    base_color = random.choice(["red", "yellow", "#00FF00"])
    odd_color = random.choice([c for c in ["red", "yellow", "#00FF00"] if c != base_color])

    # Randomize circle colors and positions
    circle_colors = [base_color] * 4
    odd_index = random.randint(0, 3)
    circle_colors[odd_index] = odd_color

    for circle, color in zip(circles, circle_colors):
        circle.fillColor = color

    # Display circles with gaze contingency
    stimulus_start_time = core.getTime()
    gaze_offset_detected = False
    gaze_offset_duration = 0
    while core.getTime() - stimulus_start_time < 1.5:  # Show circles for 1.5 seconds
        # Check for gaze position
        gaze_position = tracker.getPosition()
        if check_nodata(gaze_position):
            print("Warning: No eyes detected")
        elif check_gaze_offset(gaze_position):
            # If gaze is offset, interrupt stimulus and show indicator
            print("Gaze offset detected!")
            gaze_offset_detected = True
            offset_start_time = core.getTime()
            while check_gaze_offset(gaze_position):  # Wait until gaze returns
                draw_gazedirect(background_color_rgb)
                win.flip()
                gaze_position = tracker.getPosition()
                if check_nodata(gaze_position):
                    break  # Handle "no data" situation if needed
            gaze_offset_duration += core.getTime() - offset_start_time
        else:
            # Draw circles
            for circle in circles:
                circle.draw()
            win.flip()
        
        # Allow exit with escape key
        if event.getKeys(keyList=['escape']):
            win.close()
            core.quit()

    # Log gaze offset duration
    print(f"Gaze offset duration: {gaze_offset_duration}")
    
    actual_stimulus_duration = core.getTime() - stimulus_start_time  # Calculate the duration
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
        animation_timeout = 2.0  # Maximum 2 seconds for animation
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

    # Data logging
    stimulus_type = 'oddball' if odd_index in [0, 1] else 'standard'  # Example condition

    # Save trial data to ExperimentHandler
    trials.addData('trial_number', trial_counter + 1)
    trials.addData('stimulus_type', stimulus_type)
    trials.addData('base_color', base_color)
    trials.addData('odd_color', odd_color)
    trials.addData('odd_index', odd_index)
    trials.addData('stimulus_duration', actual_stimulus_duration)
    #trials.addData('animation_timeout', animation_timeout)
    trials.addData('auditory_cue', auditory_cue)
    trials.addData('gaze_offset_duration', gaze_offset_duration)

    # Increment trial counter
    trial_counter += 1

    # Pause between trials
    for frame in range(int(0.1 / frame_duration)):
        win.flip()

# Save and close ExperimentHandler
trials.saveAsWideText(fileName + '.csv')
exp.saveAsPickle(fileName)

# Close the window and quit
win.close()
core.quit()