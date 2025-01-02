# Rapid Sound Sequences Task Code

# Code includes: task 
# Code does not include: eye-tracking and data logging

# Task Set Up:
#  - Control Condition (CC): REG10 and RAND20 (10 Trials each)
#  - Transitions Conditions (TC): REG10-RAND20 and RAND20-REG10 (30 Trials each)
#  - Total Trial Number: 80
#  - 2 Blocks x 40 trials 
#  - Fixation Cross is visible throughout the blocks, but not in the interval btw the blocks
#  - Interval btw blocks = 8 s
#  - Interval btw trials = 2 s

# Frquency Pool Set Up
#   - Pool Size = 20 Frequencies
#   - Min Value 200 Hz, Max Value 2000 Hz
#   - The 20 frequencies are logarithmically spaced; the pool consists of the same 20 values for every trial

# Sequences Set Up:
#   - Tone Duration: 0.05 seconds
#   - REG10: choose randomly 10 tones from a frquency pool
#   - RAND20: choose randomly 20 tones with replacement from a frquency pool
#   - In every trial the tone sequences are chosen randomly from the pool

# Trials Set Up:
#   - REG10: REG10 Sequence for 12 repetitions, duration 6 seconds, the tones should be played in a pattern, no shuffle
#   - RAND20: RAND20 Sequence for 6 repetitions, duration 6 seconds, the tones are shuffled in each repetition
#   - REG10-RAND20: REG10 Sequence for 6 repetition (duration 3 seconds), followed by RAND20 Sequence for 3 repetitions(duration 3 seconds), tone are shuffled in each repetition
#   - RAND20-REG10: RAND20 Sequence for 3 repetitions (duration 3 seconds), tone are shuffled in each repetition, followed by REG10 Sequence for 6 repetition (duration 3 seconds)

# Terminate Experiment : ESC Key

# Terminal Output
#  - Block Nr, Trial Nr, Condition, Duration, Repetition Nr of the Sequence in the trial 

# Duration of the Experiment:
#   Each block: 5 min and 20 sec
#   Together: 10 min 48 sec

# Before running the code:
#  Set Up: Monitor (line 49), sound (line 56), resolution(line 63)

from psychopy import visual, core, sound, event, prefs, monitors
import numpy as np
import random

#Define Monitor
mon = monitors.Monitor(
    name='Iskra_monitor_204',
    width=59.5,  # Width in cm
    distance=60   # Viewing distance in cm
)
mon.setSizePix([1920, 1080])  # Set resolution

# Set Audio Preferences
prefs.hardware['audioLib'] = ['ptb']  # Highest precision audio backend
prefs.hardware['audioDevice'] = 'Realtek HD Audio 2nd output (Realtek(R) Audio)'  # Set audio device
prefs.hardware['audioLatencyMode'] = 3  # Low latency mode

# Create a Window
win = visual.Window(
    size=[2560, 1440],  # Set resolution to match monitor
    monitor=mon,
    units="pix",
    color=(-1, -1, -1)  # Black background
)

# Create Fixation Cross
fixation = visual.ShapeStim(
    win=win,
    vertices=((0, -80), (0, 80), (0, 0), (-80, 0), (80, 0)),
    lineWidth=5,
    closeShape=False,
    lineColor="white"
)

# Constants
DURATION_TONE = 0.05  # Duration of each tone in seconds
POOL_SIZE = 20  # Number of frequencies in the full pool
MIN_FREQ = 200  # Minimum frequency (Hz)
MAX_FREQ = 2000  # Maximum frequency (Hz)
CONTROL_TRIALS = 10  # Number of control trials per block
TRANSITION_TRIALS = 30  # Number of transition trials per block
TOTAL_TRIALS = CONTROL_TRIALS + TRANSITION_TRIALS  # Total number of trials per block
INTER_BLOCK_INTERVAL = 8  # Interval between blocks (8 seconds)
INTER_TRIAL_INTERVAL = 2  # Interval between trials (2 seconds)

# Generate a pool of log-spaced frequencies
frequency_pool = list(np.logspace(np.log10(MIN_FREQ), np.log10(MAX_FREQ), POOL_SIZE))  # Ensure it's a list

# Function to Generate a Tone
def generate_tone(frequency, duration):
    tone = sound.Sound(value=frequency, secs=duration, stereo=True)
    return tone, frequency  # Return both the tone and the frequency

# Generate REG10 Sequence (10 random tones from pool without replacement)
def generate_reg10_sequence(frequency_pool, tone_count=10):
    tones = [generate_tone(freq, DURATION_TONE) for freq in random.sample(frequency_pool, tone_count)]
    return tones  # Return the sequence of tones

# Generate RAND20 Sequence (20 random tones with replacement)
def generate_rand20_sequence(frequency_pool, tone_count=20):
    tones = [generate_tone(freq, DURATION_TONE) for freq in random.choices(frequency_pool, k=tone_count)]
    return tones  # Return the sequence of tones

# Function to play a sequence of tones for a specified number of repetitions
def play_tones(tones, repetitions=1, shuffle=True):
    played_freqs = []
    for rep_num in range(repetitions):
        if shuffle:
            # Shuffle the tones for each repetition (if required)
            random.shuffle(tones)
        
        print(f"Repetition {rep_num + 1}: ", end="")
        for tone, freq in tones:
            # Check if ESC is pressed to abort
            if 'escape' in event.getKeys():
                print("Experiment terminated by user.")
                core.quit()  # Exit the experiment immediately
            
            tone.play()
            played_freqs.append(freq)  # Append the frequency directly
            print(f"{freq:.3f}", end=" ")  # Print the frequency of the current tone
            core.wait(DURATION_TONE)  # Wait for the tone duration
            tone.stop()  # Explicitly stop each tone after playback
        print()  # New line after each repetition
    return played_freqs  # Return the list of frequencies that were played

# Function to play REG10 for 3 seconds (without shuffling)
def play_reg10_sequence_for_duration(frequency_pool, duration=3):
    tones = generate_reg10_sequence(frequency_pool)
    repetitions = int(duration / (len(tones) * DURATION_TONE))  # Calculate how many times to repeat the sequence
    played_freqs = play_tones(tones, repetitions, shuffle=False)
    return played_freqs  # Return the list of frequencies that were played

# Function to play RAND20 for 3 seconds (shuffling order for each repetition)
def play_rand20_sequence_for_duration(frequency_pool, duration=3):
    tones = generate_rand20_sequence(frequency_pool)
    repetitions = int(duration / (len(tones) * DURATION_TONE))  # Calculate how many times to repeat the sequence
    played_freqs = play_tones(tones, repetitions, shuffle=True)
    return played_freqs  # Return the list of frequencies that were played

# Function to run the experiment
def run_experiment():
    # Define the trial conditions
    conditions = ["REG10", "RAND20", "REG10-RAND20", "RAND20-REG10"]
    
    # The control condition (REG10 and RAND20) consists of 10 trials, 
    # while the transition conditions (REG10-RAND20, RAND20-REG10) consist of 30 trials.
    control_conditions = ["REG10", "RAND20"]
    transition_conditions = ["REG10-RAND20", "RAND20-REG10"]
    
    # Prepare the trial order for 2 blocks
    trial_order_block_1 = random.sample(control_conditions * 5 + transition_conditions * 15, TOTAL_TRIALS)
    trial_order_block_2 = random.sample(control_conditions * 5 + transition_conditions * 15, TOTAL_TRIALS)
    
    print("Starting Experiment")
    try:
        for block_num in range(2):  # 2 blocks
            print(f"\n--- Block {block_num + 1} ---")
            
            # For each block, run 40 trials (10 control + 30 transition)
            trial_order = trial_order_block_1 if block_num == 0 else trial_order_block_2
            
            # Block 1: Fixation Cross should disappear only during inter-trial interval
            if block_num == 0:
                fixation_visible = True  # Fixation cross visible throughout block
            else:
                fixation_visible = True  # Keep it visible in the second block as well
            
            for trial_num, condition in enumerate(trial_order, start=1):
                print(f"Trial {trial_num}: Condition {condition}, Duration 6s")
                
                # Draw fixation cross at the start of each trial (before stimulus starts)
                if fixation_visible:
                    fixation.draw()
                    win.flip()

                #core.wait(0.0)  # Very brief wait to ensure the fixation is displayed

                # Generate frequencies for the condition
                if condition == "REG10":
                    tones = generate_reg10_sequence(frequency_pool)
                    repetitions = int(6 / (len(tones) * DURATION_TONE))  # Ensure 6s playback
                    played_freqs = play_tones(tones, repetitions, shuffle=False)  # Play REG10 for 6 seconds
                    #print(f"Condition: {condition}, Frequencies played in order: {', '.join([f'{f:.3f}' for f in played_freqs])}")
                elif condition == "RAND20":
                    tones = generate_rand20_sequence(frequency_pool)
                    repetitions = int(6 / (len(tones) * DURATION_TONE))  # Ensure 6s playback
                    played_freqs = play_tones(tones, repetitions, shuffle=True)  # Play RAND20 for 6 seconds
                    #print(f"Condition: {condition}, Frequencies played in order: {', '.join([f'{f:.3f}' for f in played_freqs])}")
                elif condition == "REG10-RAND20":
                    # First 3 seconds REG10 (no shuffling)
                    played_freqs_reg10 = play_reg10_sequence_for_duration(frequency_pool, duration=3)
                    #print(f"Condition: {condition}, Frequencies played in order for REG10: {', '.join([f'{f:.3f}' for f in played_freqs_reg10])}")
                    # Then 3 seconds RAND20 (shuffling)
                    played_freqs_rand20 = play_rand20_sequence_for_duration(frequency_pool, duration=3)
                    #print(f"Condition: {condition}, Frequencies played in order for RAND20: {', '.join([f'{f:.3f}' for f in played_freqs_rand20])}")
                elif condition == "RAND20-REG10":
                    # First 3 seconds RAND20 (shuffling)
                    played_freqs_rand20 = play_rand20_sequence_for_duration(frequency_pool, duration=3)
                    #print(f"Condition: {condition}, Frequencies played in order for RAND20: {', '.join([f'{f:.3f}' for f in played_freqs_rand20])}")
                    # Then 3 seconds REG10 (no shuffling)
                    played_freqs_reg10 = play_reg10_sequence_for_duration(frequency_pool, duration=3)
                    #print(f"Condition: {condition}, Frequencies played in order for REG10: {', '.join([f'{f:.3f}' for f in played_freqs_reg10])}")
                else:
                    raise ValueError(f"Unknown condition: {condition}")

                # After the tone playback, remove fixation cross during the inter-trial interval (2 seconds)
                if block_num == 0:  # For block 1
                    fixation.setAutoDraw(False)
                    core.wait(INTER_TRIAL_INTERVAL)

            # Block Break - Fixation Cross still visible during the break between blocks
            print(f"Block {block_num + 1} completed. Taking a {INTER_BLOCK_INTERVAL}s break.")
            core.wait(INTER_BLOCK_INTERVAL)

        print("Experiment Completed")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        core.quit()  # Close experiment

# Start the experiment
run_experiment()
