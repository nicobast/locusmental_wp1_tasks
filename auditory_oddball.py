'''AUDITORY ODDBALL TASK'''
# For further information see README.md.
# IMPORTANT: select machine specific paths and audioDevice

'''LOAD MODULES'''
from psychopy import visual, core, event, clock, data, gui, monitors
import random, time, numpy
# For controlling eye tracker and eye-tracking SDK:
import tobii_research as tr
from psychopy.iohub import launchHubServer
# For getting keyboard input:
from psychopy.hardware import keyboard
# For playing sound:
from psychopy import prefs
prefs.hardware['audioLib'] = ['ptb'] # PTB described as highest accuracy sound class
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)' # define audio device - DEVICE SPECIFIC
prefs.hardware['audioLatencyMode'] = 3 # high sound priority, low latency mode
from psychopy import sound
import psychtoolbox as ptb #sound processing via ptb
# For managing paths:
from pathlib import Path
# For logging data in a .log file:
import logging
from datetime import datetime
import os # 
# Miscellaneous: Hide messages in console from pygame:
from os import environ
environ['PYGAME_HIDE_SUPPORT_PROMPT'] = '1'

'''SETUP'''
# setup logging - will be written to a file (data/logging_data):
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path("data", "auditory_oddball", "logging_data").resolve()
filename_auditory_oddball = os.path.join(logging_path, formatted_datetime)

logging.basicConfig(
    level = logging.DEBUG,
    filename = filename_auditory_oddball,
    filemode = 'w', # w = write, for each subject an separate log file.
    format = '%(asctime)s:%(levelname)s:%(name)s:%(message)s')

# welcome print
print('THIS IS AUDITORY ODDBALL.')
logging.info(' THIS IS AUDITORY ODDBALL.')

# path to output data:
path_to_data = Path("data", "auditory_oddball").resolve()
trials_data_folder = Path(path_to_data, 'trialdata')
eyetracking_data_folder = Path(path_to_data, 'eyetracking')
loggings_data_folder = Path(path_to_data, 'logging_data')

# Create folders if they don't exist
for folder in [trials_data_folder, eyetracking_data_folder, loggings_data_folder]:
    folder.mkdir(parents=True, exist_ok=True)

# Print paths
print(trials_data_folder)
print(eyetracking_data_folder)
print(loggings_data_folder)

# Log paths
logging.info(f'Trials data folder: {trials_data_folder}')
logging.info(f'Eyetracking data folder: {eyetracking_data_folder}')
logging.info(f'Logging data folder: {loggings_data_folder}')

# testmode options
# testmode_et = TRUE mimics an eye-tracker by mouse movement, FALSE = eye-tracking hardware is required and adressed with tobii_research module
# testmode_eeg = TRUE mimics an parallel port trigger an on-screen notation, FALSE = parallel port is available and defined, search "parallel_port_adress"
testmode_et = False

# Experimental settings:
# Input dialogue boxes are presented on external screen 0.
dialog_screen = 1
# Stimuli are presented on internal screen 1.
presentation_screen = 0
number_of_repetitions = 20 
number_of_repetition_standards = 1
stimulus_duration_in_seconds = 0.1
# If oddball or standrad stimulus is defined below.
sound_one_in_Hz = 500
sound_two_in_Hz = 750
size_fixation_cross_in_pixels = 60
# Inter Stimulus Interval (ISI) randomly varies between value0 and value1.
ISI_interval = [1800, 2000]
# Sensitivity: Warning of gaze offset from the center.
gaze_offset_cutoff = 3 * size_fixation_cross_in_pixels
# [0, 0 , 0] is gray as float [-1, 1]
background_color_rgb = (0, 0, 0)
white_slide = 'white'
black_slide = 'black'
manipulation_repetition = 5 
# Presentation duration of baseline screen, in seconds.
baseline_duration = 5
baseline_calibration_repetition = 1 
# After 500 ms the no_data detection warning should be displayed on the screen.no_data_warning_cutoff = 0.5
no_data_warning_cutoff = 0.5
# Settings are stored automatically for each trial.
settings = {}

# hardware setting
sampling_rate = 60 # Tobii Pro Spark = 60Hz, Tobii Pro Spectrum = 300Hz, Tobii TX-300 (ATFZ) = 300 Hz
parallel_port_adress = 0x03FF8 #required for EEG triggers
pulse_duration = 0.01 # EEG trigger variables. 10 ms duration of trigger signal.


# Presenting a dialog box. Infos are added to settings.
settings['id'] = 123 #default testing value
#settings['group'] = ['ASD', 'TD'] #extra lines can pass additional info to experiment file
#settings['luminance'] = 0 #extra lines can pass additional info to experiment file
# Create a dialog box for participant info
exp_info = {
    "Participant ID": "",
    "Timepoint": ["test", "pilot", "T1", "T2", "T3"]
}

dlg = gui.DlgFromDict(
    dictionary=exp_info,
    title= "auditory oddball",
    order=["Participant ID", "Timepoint"] # Order of fields
   
)
if not dlg.OK:
    logging.warning("Experiment canceled by the user.")
    core.quit()

participant_id = exp_info["Participant ID"]
timepoint = exp_info["Timepoint"]

logging.info(f"Participant ID: {participant_id}")
logging.info(f"Timepoint: {timepoint}")

selected_timepoint = timepoint[0]  # Get the first item from the list

# Name for output data:
# participant_id and selected_timepoint come from the dialog box input
fileName = f'auditory_{participant_id}_{selected_timepoint}_{data.getDateStr(format="%Y-%m-%d-%H%M")}'

# Experiment handler saves experiment data automatically.
# The dictionary "settings" is passed to the experiment handler.
exp = data.ExperimentHandler(
    name="auditory_oddball",
    version='0.2',
    extraInfo = settings,
    dataFileName = str(trials_data_folder / fileName),
    )

# Two different sound frequencies (conditions) are balanced across groups and
# saved in the settings dictionary:
random_number = random.random()
if random_number < 0.5:
    standard_sound = sound.Sound(sound_one_in_Hz, stereo=False)
    oddball_sound = sound.Sound(sound_two_in_Hz, stereo=False)
    sound_standard = sound_one_in_Hz
    sound_oddball = sound_two_in_Hz
    print('oddball sound is ', sound_two_in_Hz,' Hz')
    logging.info(' ODDBALL SOUND IS : ' f'{sound_two_in_Hz}' ' Hz')
    settings['standard_frequency'] = sound_one_in_Hz
    settings['oddball_frequency'] = sound_two_in_Hz

if random_number >= 0.5:
    standard_sound = sound.Sound(sound_two_in_Hz, stereo=False)
    oddball_sound = sound.Sound(sound_one_in_Hz, stereo=False)
    sound_standard = sound_two_in_Hz
    sound_oddball = sound_one_in_Hz
    print('oddball sound is ', sound_one_in_Hz,' Hz')
    logging.info(' ODDBALL SOUND IS : ' f'{sound_one_in_Hz}' ' Hz')
    settings['standard_frequency'] = sound_two_in_Hz 
    settings['oddball_frequency'] = sound_one_in_Hz 

# Monitor parameters are adapted to presentation PC.
# Name is saved with PsychoPy monitor manager.
# units (width, distance) are in cm.
mon = monitors.Monitor(
    name = 'Iskra_monitor_204',
    width = 59.5,
    distance = 60)

# Create display window.
# Unit was changed to pixel so that eye trcker outputs pixel on presentation screen.
mywin = visual.Window(
    size = [2560,1440],
    fullscr=True,
    monitor = mon,
    color = background_color_rgb,
    screen = presentation_screen,
    units = "pix")

refresh_rate = mywin.monitorFramePeriod #get monitor refresh rate in seconds
print('monitor refresh rate: ' + str(round(refresh_rate, 3)) + ' seconds')

#Setup Eye Tracking:
if testmode_et:
    logging.info('TESTMODE = TRUE')
    print('Mouse is used to mimic eye tracker...')
    iohub_config = {
        'eyetracker.hw.mouse.EyeTracker': {'name': 'tracker'}
    }
else:
    logging.info('TESTMODE = FALSE')
    
    # Search for eye trackers:
    found_eyetrackers = tr.find_all_eyetrackers()
    if not found_eyetrackers:
        raise RuntimeError("No eye tracker found. Please check the connection.")
    
    # Select the first available eye tracker:
    my_eyetracker = found_eyetrackers[0]
    sampling_rate = my_eyetracker.get_all_gaze_output_frequencies()[0]
    
    # Log eye tracker details:
    print(f"Tracker connected:\n"
          f"Address: {my_eyetracker.address}\n"
          f"Model: {my_eyetracker.model}\n"
          f"Sampling Rates: {my_eyetracker.get_all_gaze_output_frequencies()}")
    logging.info(f"ADDRESS: {my_eyetracker.address}")
    logging.info(f"MODEL: {my_eyetracker.model}")
    logging.info(f"SERIAL NUMBER: {my_eyetracker.serial_number}")

    # Define ioHub configuration:
    iohub_config = {
        'eyetracker.hw.tobii.EyeTracker': {
            'name': 'tracker',
            'runtime_settings': {'sampling_rate': sampling_rate}
        }
    }

# Launch ioHub server:
io = launchHubServer(
    **iohub_config,
    experiment_code=str(eyetracking_data_folder),
    session_code=fileName,
    datastore_name=str(eyetracking_data_folder / fileName),
    window=mywin
)

# Initialize tracker
tracker = io.devices.tracker
if not tracker:
    raise RuntimeError("Tracker initialization failed. Please check your eye tracker configuration.")

# Start eye tracker recording
print("Tracker successfully initialized!")
tracker.setRecordingState(True)

# SETUP KEYBORD
kb = keyboard.Keyboard()

# Draw a fixation cross from lines:
def draw_fixcross(background_color=background_color_rgb, cross_color = 'black'):
    if background_color is not background_color_rgb:
        background_rect = visual.Rect(win=mywin, size=mywin.size, fillColor= background_color)
        background_rect.draw()
    line1 = visual.Line(win=mywin, units='pix', lineColor = cross_color) #define line object
    line1.start = [-(size_fixation_cross_in_pixels/2), 0]
    line1.end = [+(size_fixation_cross_in_pixels/2), 0]
    line2 = visual.Line(win=mywin, units='pix', lineColor = cross_color) #define line object
    line2.start = [0, -(size_fixation_cross_in_pixels/2)]
    line2.end = [0, +(size_fixation_cross_in_pixels/2)]
    line1.draw()
    line2.draw()

# Draw figure when gaze is offset for gaze contigency:
def draw_gazedirect(background_color=background_color_rgb):
    # Adapt background according to provided "background_color"
    if background_color is not background_color_rgb:
        background_rect = visual.Rect(
            win = mywin,
            size = mywin.size,
            fillColor = background_color)
        background_rect.draw()
    function_color = 'red'
    arrow_size_pix = size_fixation_cross_in_pixels
    arrow_pos_offset = 5
    width = 3

    rect1 = visual.Rect(
        win = mywin,
        units = 'pix',
        lineColor = function_color,
        fillColor = background_color,
        lineWidth = width,
        size = size_fixation_cross_in_pixels*6)

    # Arrow left:
    al_line1 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    al_line1.start = [-(arrow_size_pix*arrow_pos_offset), 0]
    al_line1.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    al_line2 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    al_line2.start = [-(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), -arrow_size_pix/2]
    al_line2.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    al_line3 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    al_line3.start = [-(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), +arrow_size_pix/2]
    al_line3.end = [-(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]

    # Arrow right:
    ar_line1 = visual.Line(win = mywin, units='pix', lineColor = function_color, lineWidth = width)
    ar_line1.start = [+(arrow_size_pix*arrow_pos_offset), 0]
    ar_line1.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    ar_line2 = visual.Line(win = mywin, units='pix', lineColor = function_color, lineWidth = width)
    ar_line2.start = [+(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), -arrow_size_pix/2]
    ar_line2.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]
    ar_line3 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    ar_line3.start = [+(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2)), +arrow_size_pix/2]
    ar_line3.end = [+(arrow_size_pix*arrow_pos_offset-arrow_size_pix), 0]

    # Arrow top:
    at_line1 = visual.Line(win = mywin, units='pix', lineColor = function_color, lineWidth = width)
    at_line1.start = [0, +(arrow_size_pix*arrow_pos_offset)]
    at_line1.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    at_line2 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    at_line2.start = [-arrow_size_pix/2, +(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    at_line2.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    at_line3 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    at_line3.start = [+arrow_size_pix/2, +(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    at_line3.end = [0, +(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]

    # Arrow bottom:
    ab_line1 = visual.Line(win = mywin, units='pix', lineColor = function_color, lineWidth = width)
    ab_line1.start = [0, -(arrow_size_pix*arrow_pos_offset)]
    ab_line1.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    ab_line2 = visual.Line(win = mywin, units = 'pix', lineColor = function_color, lineWidth = width)
    ab_line2.start = [+arrow_size_pix/2, -(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    ab_line2.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]
    ab_line3 = visual.Line(win = mywin, units='pix', lineColor = function_color, lineWidth = width)
    ab_line3.start = [-arrow_size_pix/2, -(arrow_size_pix*arrow_pos_offset-(arrow_size_pix/2))]
    ab_line3.end = [0, -(arrow_size_pix*arrow_pos_offset-arrow_size_pix)]

    #draw all
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

# Check for keypresses, used to pause and quit experiment:
def check_keypress():
    keys = kb.getKeys(['p','escape'], waitRelease = True)
    timestamp_keypress = clock.getTime()

    # Extract key names from the KeyPress objects and print them
    key_names = [key.name for key in keys]
    #print(f"Keys pressed: {key_names}")  # Debug: print the key names

    if 'escape' in keys:
        dlg = gui.Dlg(title='Quit?', labelButtonOK=' OK ', labelButtonCancel=' Cancel ')
        dlg.addText('Do you really want to quit? - Then press OK')
        dlg.show()  # show dialog and wait for OK or Cancel
        if dlg.OK:  # or if ok_data is not None
            print('EXPERIMENT ABORTED!')
            core.quit()
        else:
            print('Experiment continues...')
        pause_time = clock.getTime() - timestamp_keypress

    elif 'p' in keys:
        dlg = gui.Dlg(title='Pause', labelButtonOK='Continue')
        dlg.addText('Experiment is paused - Press Continue, when ready')
        dlg.show()  # show dialog and wait for OK
        pause_time = clock.getTime() - timestamp_keypress
    else:
        pause_time = 0
        # Show the experiment window again
    pause_time = round(pause_time,3)
    return pause_time

def check_nodata(gaze_position):
    if gaze_position == None:
        nodata_boolean = True
    else:
        nodata_boolean = False
    return nodata_boolean

# Get gaze position and offset cutoff.
# Then check for the offset of gaze from the center screen.
def check_gaze_offset(gaze_position):
    gaze_center_offset = numpy.sqrt((gaze_position[0])**2 + (gaze_position[1])**2) #pythagoras theorem
    if gaze_center_offset >= gaze_offset_cutoff:
        offset_boolean = True
    else:
        offset_boolean = False
    return offset_boolean

# Fixation cross: Check for data availability and screen center gaze.
def fixcross_gazecontingent(duration_in_seconds, background_color = background_color_rgb, cross_color = 'black'):
    # Translate duration to number of frames:
    number_of_frames = round(duration_in_seconds/refresh_rate)
    timestamp = core.getTime()
    gaze_offset_duration = 0
    pause_duration = 0
    nodata_duration = 0
    # Cross presentation for number of frames:
    for frameN in range(number_of_frames):
        # Check for keypress:
        pause_duration += check_keypress()
        # Check for eye tracking data, only call once per flip:
        gaze_position = tracker.getPosition()
        # Check for eye tracking data:
        if check_nodata(gaze_position):
            print('warning: no eyes detected')
            logging.warning(' NO EYES DETECTED')
            frameN = 1 # reset duration of for loop - resart ISI
            nodata_current_duration = 0

            while check_nodata(gaze_position):
                mywin.flip() #wait for monitor refresh time
                nodata_duration += refresh_rate
                nodata_current_duration += refresh_rate
                gaze_position = tracker.getPosition() #get new gaze data
        # Check for gaze:
        elif check_gaze_offset(gaze_position):
            print('warning: gaze offset')
            frameN = 1 #reset duration of for loop - resart ISI

            while not check_nodata(gaze_position) and check_gaze_offset(gaze_position):
                # Listen for keypress:
                pause_duration += check_keypress()
                draw_gazedirect(background_color) #redirect attention to fixation cross area
                mywin.flip() #wait for monitor refresh time
                gaze_offset_duration += refresh_rate
                gaze_position = tracker.getPosition() #get new gaze data
        # Draw fixation cross:
        draw_fixcross(background_color, cross_color)
        mywin.flip()

    # Generate output info:
    actual_fixcross_duration = round(core.getTime()-timestamp,3)
    gaze_offset_duration = round(gaze_offset_duration,3)
    nodata_duration = round(nodata_duration,3)

    print('numberof frames: ' + str(number_of_frames))
    logging.info(' NUMBER OF FRAMES: ' f'{number_of_frames}')
    print('no data duration: ' + str(nodata_duration))
    logging.info(' NO DATA DURATION: ' f'{nodata_duration}')
    print('gaze offset duration: ' + str(gaze_offset_duration))
    logging.info(' GAZE OFFSET DURATION: ' f'{gaze_offset_duration}')
    print('pause duration: ' + str(pause_duration))
    logging.info(' PAUSE DURATION: ' f'{pause_duration}')
    print('actual fixcross duration: ' + str(actual_fixcross_duration))
    logging.info(' ACTUAL FIXCROSS DURAION: ' f'{actual_fixcross_duration}')

    return [actual_fixcross_duration, gaze_offset_duration, pause_duration, nodata_duration]

# Auditory oddball stimulus:
def present_stimulus(duration_in_seconds, trial):
    nextFlip = mywin.getFutureFlipTime(clock='ptb') # sync sound start with next screen refresh
    if trial == 'oddball':
        if sound_oddball == sound_one_in_Hz or sound_oddball == sound_two_in_Hz:
            logging.info(f' ODDBALL WAS PLAYED IN: {sound_oddball} Hz')
            oddball_sound.play(when=nextFlip)

    if trial == 'standard':
        if sound_standard == sound_one_in_Hz or sound_standard == sound_two_in_Hz:
            logging.info(f' STANDARD WAS PLAYED IN: {sound_standard} Hz')
            standard_sound.play(when=nextFlip)

    if trial == 'oddball_rev':
        if sound_oddball == sound_two_in_Hz or sound_oddball == sound_one_in_Hz:
            logging.info(f' ODDBALL_REV WAS PLAYED IN: {sound_standard} Hz')
            standard_sound.play(when=nextFlip)

    if trial == 'standard_rev':
        if sound_standard == sound_two_in_Hz or sound_standard == sound_one_in_Hz:
            logging.info(f' STANDARD_REV WAS PLAYED IN: {sound_oddball} Hz')
            oddball_sound.play(when=nextFlip)

    number_of_frames = round(duration_in_seconds/refresh_rate) 
    # Present cross for number of frames:
    timestamp = clock.getTime()
    for frameN in range(number_of_frames):
        draw_fixcross()
        mywin.flip()
    # Stop replay:
    if trial == 'oddball':
        oddball_sound.stop()
    if trial == 'standard':
        standard_sound.stop()
    if trial == 'oddball_rev':
        standard_sound.stop()
    if trial == 'standard_rev':
        oddball_sound.stop()
    # Function output
    actual_stimulus_duration = round(clock.getTime()-timestamp,3)
    print(trial + " duration:",actual_stimulus_duration)
    logging.info(' ' f'{trial}' ' DURATION: ' f'{actual_stimulus_duration}')
    return actual_stimulus_duration

# Random interstimulus interval (SI):
def define_ISI_interval():
    ISI = random.randint(ISI_interval[0], ISI_interval[1])
    ISI = ISI/1000 #get to second format
    return ISI

'''EXPERIMENTAL DESIGN'''
# The trial handler calls the sequence and displays it randomized.
# Loop of block is added to experiment handler.
# Any data that is collected will be transferred to experiment handler automatically.
phase_sequence = [
    'baseline_calibration',
    'oddball_block',
    'baseline']

phase_handler = data.TrialHandler(phase_sequence,nReps = 1, method = 'sequential') 
exp.addLoop(phase_handler) 

# Global variables:
block_counter = 0
baseline_trial_counter = 1

oddball_trial_counter = 1 # trials in oddball_blocks
standard_trial_counter = 1 #trials in oddball_blocks

for phase in phase_handler:
    block_counter += 1 

    if phase == 'oddball_block':
        # Sequence for trial handler with 1/5 chance for an oddball.
        stimulus_sequence = ['standard','standard','standard','standard','oddball'] 
        # Define a seq uence for trial handler with 3 standard stimuli.
        standard_sequence = ['standard', 'standard', 'standard']
        # Trial handler calls the stimulus_sequence and displays it randomized.
        trials = data.TrialHandler(stimulus_sequence, nReps = number_of_repetitions, method = 'random')
        # Trial handler for 3 standard stimuli.
        standards = data.TrialHandler(standard_sequence, nReps = number_of_repetition_standards, method = 'sequential')
        # Add loop of block to experiment handler. Any collected data will be transferred to experiment handler automatically.
        exp.addLoop(trials)
        print('START OF ODDBALL BLOCK')
        logging.info(' START OF ODDBALL BLOCK.')

        # Continuing counting after last oddball_block...
        standard_trial_counter = oddball_trial_counter
        
        for standard in standards:
            ISI = define_ISI_interval()
            timestamp = time.time()
            timestamp_exp = core.getTime()
            timestamp_tracker = tracker.trackerTime()
            print('NEW TRIAL')
            logging.info(' NEW TRIAL')
            print("ISI: ", ISI)
            logging.info(' ISI: ' f'{ISI}')
            print("gaze position: ",tracker.getPosition())
            logging.info(' GAZE POSITION: ' f'{tracker.getPosition()}')
            # Stimulus presentation:
            actual_stimulus_duration = present_stimulus(stimulus_duration_in_seconds, trial = standard)
            [fixcross_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(ISI)

            # Save data in .csv file:
            # Information about each phase:
            phase_handler.addData('phase', phase)
            phase_handler.addData('block_counter', block_counter)
            # Information about each trial: 
            trials.addData('oddball_trial_counter', standard_trial_counter)
            trials.addData('trial', standard) 
            trials.addData('stimulus_duration', actual_stimulus_duration)
            trials.addData('ISI_expected', ISI)
            trials.addData('ISI_duration', fixcross_duration)
            trials.addData('gaze_offset_duration', offset_duration)
            trials.addData('trial_pause_duration', pause_duration)
            trials.addData('trial_nodata_duration', nodata_duration)
            trials.addData('timestamp', timestamp) 
            trials.addData('timestamp_exp', timestamp_exp) 
            trials.addData('timestamp_tracker', timestamp_tracker)
            
            standard_trial_counter += 1
            exp.nextEntry()

        # Continuing counting after 3 standard trials...
        oddball_trial_counter = standard_trial_counter

        for trial in trials:
            ISI = define_ISI_interval() 
            timestamp = time.time() 
            timestamp_exp = core.getTime() 
            timestamp_tracker = tracker.trackerTime()
            print('NEW TRIAL')
            logging.info(' NEW TRIAL')
            print("ISI: ",ISI)
            logging.info(' ISI: ' f'{ISI}')
            print("gaze position: ",tracker.getPosition())
            logging.info(' GAZE POSITION: ' f'{tracker.getPosition()}')
            # Stimulus presentation:
            actual_stimulus_duration = present_stimulus(stimulus_duration_in_seconds, trial)
            [fixcross_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(ISI)

            # Save data in .csv file:
            # Information about each phase:
            phase_handler.addData('phase', phase)
            phase_handler.addData('block_counter', block_counter)
            # Information about each trial:
            trials.addData('oddball_trial_counter',oddball_trial_counter) 
            trials.addData('trial', trial) 
            trials.addData('timestamp', timestamp) #seconds since 01.01.1970 (epoch)
            trials.addData('timestamp_exp', timestamp_exp) 
            trials.addData('timestamp_tracker', timestamp_tracker) 
            trials.addData('stimulus_duration', actual_stimulus_duration)
            trials.addData('ISI_expected', ISI)
            trials.addData('ISI_duration', fixcross_duration)
            trials.addData('gaze_offset_duration', offset_duration)
            trials.addData('trial_pause_duration', pause_duration)
            trials.addData('trial_nodata_duration', nodata_duration)

            oddball_trial_counter += 1
            exp.nextEntry()

    if phase == 'baseline':
        print('START OF BASELINE PHASE')
        logging.info(' START OF BASELINE PHASE')
        timestamp = time.time() 
        timestamp_exp = core.getTime() 
        [stimulus_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(baseline_duration)

        # Save data in .csv file:
        # Informatiom about each phase:
        phase_handler.addData('phase', phase)
        phase_handler.addData('block_counter', block_counter)
        # Information about each trial:
        phase_handler.addData('stimulus_duration', stimulus_duration)
        phase_handler.addData('gaze_offset_duration', offset_duration)
        phase_handler.addData('trial_pause_duration', pause_duration)
        phase_handler.addData('trial_nodata_duration', nodata_duration)
        phase_handler.addData('baseline_trial_counter',baseline_trial_counter)
        phase_handler.addData('trial', phase)
        phase_handler.addData('timestamp', timestamp)
        phase_handler.addData('timestamp_exp', timestamp_exp)

        baseline_trial_counter += 1
        exp.nextEntry()

    # During calibration process, pupil dilation (black slide) and
    # pupil constriction (white slide) are assessed.
    if phase == 'baseline_calibration':
        # Setup experimental manipulation:
        baseline_sequence = ['baseline','baseline_whiteslide','baseline_blackslide']
        baseline_calibration_repetition = baseline_calibration_repetition
        exp_baseline_calibration = data.TrialHandler(baseline_sequence,nReps = baseline_calibration_repetition, method='sequential') 
        exp.addLoop(exp_baseline_calibration) 
        print('START OF BASELINE CALIBRATION PHASE')
        logging.info(' START OF BASELINE CALIBRATION PHASE')

        for baseline_trial in baseline_sequence:
            if baseline_trial == 'baseline':
                timestamp = time.time() 
                timestamp_exp = core.getTime()
                [stimulus_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(baseline_duration)

                # Save data in .csv file:
                # Information about each phase:
                phase_handler.addData('phase', phase)
                phase_handler.addData('block_counter', block_counter)
                # Information about each trial:
                phase_handler.addData('stimulus_duration', stimulus_duration)
                phase_handler.addData('gaze_offset_duration', offset_duration)
                phase_handler.addData('trial_pause_duration', pause_duration)
                phase_handler.addData('trial_nodata_duration', nodata_duration)
                phase_handler.addData('baseline_trial_counter',baseline_trial_counter)
                phase_handler.addData('trial', baseline_trial)
                phase_handler.addData('timestamp', timestamp)
                phase_handler.addData('timestamp_exp', timestamp_exp)

                baseline_trial_counter += 1
                exp.nextEntry()

            # Present baseline with white background:
            if baseline_trial == 'baseline_whiteslide':
                timestamp = time.time() 
                timestamp_exp = core.getTime()
                [stimulus_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(baseline_duration, background_color = white_slide)

                # Save data in .csv file:
                # Information about each phase:
                phase_handler.addData('phase', phase)
                phase_handler.addData('block_counter', block_counter)
                # Information about each trial:
                phase_handler.addData('stimulus_duration', stimulus_duration)
                phase_handler.addData('gaze_offset_duration', offset_duration)
                phase_handler.addData('trial_pause_duration', pause_duration)
                phase_handler.addData('trial_nodata_duration', nodata_duration)
                phase_handler.addData('baseline_trial_counter',baseline_trial_counter)
                phase_handler.addData('trial', baseline_trial)
                phase_handler.addData('timestamp', timestamp)
                phase_handler.addData('timestamp_exp', timestamp_exp)

                exp.nextEntry()

            if baseline_trial == 'baseline_blackslide':
                timestamp = time.time() 
                timestamp_exp = core.getTime()
                # Present baseline with black background:
                [stimulus_duration, offset_duration, pause_duration, nodata_duration] = fixcross_gazecontingent(baseline_duration, background_color = black_slide, cross_color = 'grey')

                # Save data in .csv file:
                # Information about each phase:
                phase_handler.addData('phase', phase)
                phase_handler.addData('block_counter', block_counter)
                # Information about each trial:
                phase_handler.addData('stimulus_duration', stimulus_duration)
                phase_handler.addData('gaze_offset_duration', offset_duration)
                phase_handler.addData('trial_pause_duration', pause_duration)
                phase_handler.addData('trial_nodata_duration', nodata_duration)
                phase_handler.addData('baseline_trial_counter',baseline_trial_counter)
                phase_handler.addData('trial', baseline_trial)
                phase_handler.addData('timestamp', timestamp)
                phase_handler.addData('timestamp_exp', timestamp_exp)

                exp.nextEntry()

   # logging.info(f"Saving data to: {trials_data_folder / fileName}")
   # exp.saveAsWideText(str(trials_data_folder / fileName), delim=",")   

    
print("Trial data in phase_handler:", phase_handler.trialList)
# Explicitly save after the data is logged


'''WRAP UP AND CLOSE'''
# Send trigger that experiment has ended:
print('EXPERIMENT ENDED')
logging.info(' EXPERIMENT ENDED.')
# Close reading from eyetracker:
tracker.setRecordingState(False)
# Close iohub instance:
io.quit()
# Close window:
mywin.close()
core.quit()