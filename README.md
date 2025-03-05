# Tasks LOCUS-MENTAL

## Overview 
This study consists of four tasks:
* an passive auditory Oddball Task (auditory_oddball.py)
* an active visual Oddball Task (visual_oddball.py)
* regularity in rapid sound sequences (rapid-sound-sequences.py)
* cued visual search (cued-visual-search-animation.py)

During all tasks, pupil dilation is measured via eye tracking. Several baseline phases are used to determine tonic pupil size. 

# Installation Guide for Python and Required Modules
## Python Installation
* The required Python module tobii-research is compatible only with Python 3.10. Therefore, ensure you install Python 3.10 according to your system requirements or create a virtual environment that uses Python 3.10.
* Do not download Python from the Microsoft Store, as it is treated as an app, which can cause conflicts. Instead, download Python directly from the official website: https://www.python.org/downloads/windows/.
  * When running the installer (.exe file):
      1. Run it as Administrator.
      2. Check the box "Add PYTHON to PATH" to automatically set the environment variable: "python" command is enabled within terminal.
## Working with Multiple Python Versions
* If you have multiple Python versions installed, you can create a virtual environment specifically for Python 3.10 in the terminal:
  * Check the Python version available: python --version
  * Create a virtual environment using Python 3.10: python3.10 -m venv environment_name (py -3.10 -m venv environment_name)
  * Activate the virtual environment: environment_name\Scripts\activate
## Installing Required Modules
 * Installation requires "Microsoft Visual C++ 14.0" bundled with "Microsoft C++ Build Tools" (Desktop Development with C++).
 * you use a virtual environment, all modules must be installed within that activate environment:
  1. Psychopy: Install version 2023.1.3, as newer versions may not be compatible : pip install psychopy==2023.1.3
  2. NumPy: Install version 1.23.5: pip install numpy==1.23.5
  3. Tobii Pro SDK as Tobii Research Python module: pip install tobii_research
  4. Verify installation of Psychopy and Numpy using: pip list
  5. additional modules required by the script (e.g., sounddevice or ptb) are missing, install them as well: pip install module_name

## Submodule iohub
 * Issue: during task execution, an error in one of the module files occured prevented the recording of gaze data.
  - ERROR: KeyError: 'right_gaze_origin_in_trackbox_coordinate_system'
  - Problem Background: The KeyError occurs because the code attempts to access a non-existing key 'right_gaze_origin_in_trackbox_coordinate_system', in the gaze data returned by the Tobii eye tracker. In the tobii-research module, the correct keys are: 'right_gaze_origin_in_user_coordinate_system' instead.
  - Solution: 
    1.  Locate the following file in your Python environment: <Python Environment Directory>lib\site-packages\psychopy\iohub\devices\eyetracker\hw\tobii\eyetracker.py
    2.  Find lines 433 and 434 and replace them with the following corrected code:
        right_gx, right_gy, right_gz = eye_data_event['right_gaze_origin_in_user_coordinate_system']
        left_gx, left_gy, left_gz = eye_data_event['left_gaze_origin_in_user_coordinate_system']

## Install presentation PC:
  * PREFERED: download and install standalone version of psychopy: https://www.psychopy.org/download.html
    --> run scripts from built-in python instance
  * required eye tracker package for python needs to be installed from CMD as administrator: "C:\Program Files\PsychoPy\python.exe" -m pip install psychopy-eyetracker-tobii
  
## run task:
* open project folder with python scripts of experiment, e.g.: "C:\Users\nico\PowerFolders\project_locusmental_wp1"
* open CMD by typing "cmd" into file browser
* in CMD execute script of task with standalone psychopy version:
* requires location of psychopy stanalone version: e.g: "C:\Program Files\PsychoPy\python.exe"
* requires location of script e.g.: "C:\Users\nico\PowerFolders\project_locusmental_wp1\auditory_oddball.py"
* then run in CMD: "C:\Program Files\PsychoPy\python.exe" "C:\Users\nico\PowerFolders\project_locusmental_wp1\auditory_oddball_core.py"

## Monitor and display settings

Monitor settings are configured in the experiment's config.json file. This file contains all paths, device settings,audio and monitor configurations, ensuring that the experiment is set up correctly for the presentation PC. Please note the following:

 * Device Configuration: All device settings, including monitor parameters, are defined in the config.json file. The monitor name is saved with the PsychoPy Monitor Manager, ensuring compatibility with the experiment setup.
 * Avoid Integrated Graphics: It is recommended to avoid using integrated graphics for experiment computers, as they may lack accurate frame timing, which is crucial for precise stimulus presentation.
 * Windows Scaling: Set the Windows scaling to 100%. Any scaling other than 100% may result in incorrect onscreen units, causing display issues in the experiment.
 * Experiment Screen: The experiment is designed to run on a Full HD screen with a resolution of 2550x1440. Please ensure that the system’s display settings reflect this resolution for accurate stimulus presentation.

## Eye tracking
* difference to psychopy documentation required: Define name as tracker and define a presentation window before.
* in case testmode = True: the mouse is used as eyetracker and data stored in hdf5 file: -> import h5py -> access data: dset1 = f['data_collection/events/eyetracker/MonocularEyeSampleEvent']

## Run All Tasks(Run the Battery)
  To run the task, follow these steps:

  Modify the config.json file:
  * Adjust the following settings based on your setup:
      - Modify path to environment accordingly
          - If your environment is set up outside of the project folder, the task will not run correctly. Adjust the paths in the config.json to point to the correct directories. The paths in this file need to be accurate to avoid errors in loading resources or devices.
          - If your environment is in the your project folder, then you can modify the config.json and delete the environment and task paths.
      - Modify paths to tasks accordingly
      - Monitor & Audio Settings: Configure display and sound settings as needed.
      - Testmode: TRUE/FALSE testmode depending on your requirements(eyetracker available or not)

  * Run the Task
      - Execute the Runner script.
  
  * Run one task
    - If you want to run only one specific task in the experiment, you can do so by modifying the tasks [] list in the runner.py file. To exclude a task from being executed, simply add a '#' symbol in front of the task name in the tasks [] list. This will comment out the task, and it will not be run when you execute the script.

## The Auditory Oddball Task
The task is used to manipulate Locus-Coeruleus-Norepinephrine (LC-NE) activity. In four task blocks, each including 100 trials, a frequent tone (standard) is presented with a probability of 80% while an infrequent tone of a different pitch (oddball) is presented with a probability of 20%. The pitch level indicating oddballs in the 1st task block and the 3rd task block (oddball blocks) are either 500 Hz or 750 Hz. Oddballs in the 2nd and 4th task block are of the opposite pitch (oddball blocks reverse). Three additional standard trials precede each task block.  

### Task sequence
1. baseline fixation
2. oddball task

## The Visual Oddball Task
The task is used and to observe effects of task utility and stimulus salience. It contains independent manipulations of both.The task consists of 75 trials. A frequent blue circle is presented with a probability of 80% (standard trials), while an infrequent larger blue circle (oddball trials) appears with a probability of 20%. Oddball trials are designed to be presented only after at least two standard trials. The task begins with a fixation cross displayed for 5 seconds.

### Automatic conversion of visual angle to pixels in script
* *size_fixation_cross_in_pixels = 132*, also defines standard stimulus size and translates to 3.2 degrees visual angle on 24 inch screen with 25.59 inches screen distance (see https://elvers.us/perception/visualAngle/)
* *high_salience_ball_size = round(0.5 * size_fixation_cross_in_pixels)* translates to 1.6 degrees visual angle on 24 inch screen with 25.59 inches screen distance.
* *low_salience_ball_size = round(0.91 * size_fixation_cross_in_pixels)* translates to 2.9 degrees visual angle on 24 inch screen with 25.59 inches screen distance.


# Cued Visual Search Task
* File: cued-visual-search-animation.py

 This task involves a visual search paradigm with an auditory cue before the search phase. It consists of 30 trials, each following a structured sequence of events.
 * Task Structure
   A. Initial Fixation Phase: a black fixation cross is presented at the center of a grey screen for 5 seconds before the trials begin.
   B. Trial Structure:
    - each trial consist of:
      1. Inter Stimulus Interval
        - fixation cross displayed for 1.5 seconds
      2. Pre-search Period (400ms)
        - in 50 % of the trials, an auditory cue (beep) is played
        - the auditory cue occurs with random delay between 0 to 100 ms
        - the beep duration is randomly selected between 200 and 300 ms
        - the remaining time within the 400 ms period is a blank grey screen
        - in no-cue trials, a blank grey screen is displayed for the full 400 ms
      3. Visual Search 
        - four circles appear on the screen, positioned top, bottom , left and right
        - three circles "distractors" are in one randomly chosen base color (isoluminant red, green or yellow color)
        - the fourth "target" circle appears in randomly selected base color different from the distractors 
        - the target circle's position is randomly assigned in each trial


# Rapid Sound Sequences
 * File: rapid-sound-sequences.py
 
## Task Description
  1.  Overview
  This task presents a series of auditory stimuli (tones of varying frequencies) in rapid succession. The goal is to investigate auditory pattern recognition and transition effects between structured and unstructured sound sequences.
  The task consists of five conditions:
  * Two control conditions:
    - RAND20: Random sequence of tones.
    - REG10: Structured, repeating sequence of tones.
  * Three transition conditions:
    - RAND20 → REG10: Transition from a random to a structured sequence.
    - RAND20 → REG1: Transition from a random sequence to a single repeating tone.
    - REG10 → RAND20: Transition from a structured to a random sequence.

  2. Stimulus Construction
    A. Tone Pool
      - The tones are logarithmically spaced between 200 Hz and 2000 Hz
      - Each sequence is constructed by selecting tones from this pool
      - Each tone has a duration of 0.05 s
    B. Control Conditions
      1. REG10 (Regular 10 Tones Sequence)
        - 10 tones are selected from the pool and arranged in a fixed random sequence
        - the same sequence is repeated 12 times (for a total of 6 seconds)
      2. RAND20 (Random 20 Tones Sequence)
        - 20 tones are selected from the pool with replacement and played in a randomized order in each sequence
        - The random sequence is repeated 6 times to achieve 6 seconds trial duration
    C. Transition Conditions
      1. RAND20 → REG10:
        - The RAND20 sequence is played for 3 seconds.
        - The REG10 sequence follows for 3 seconds (6 repetitions).
      2. RAND20 → REG1:
        - The RAND20 sequence is played for 3 seconds.
        - REG1 consists of a single tone from the pool, which is played repeatedly for 3 seconds.
      3. REG10 → RAND20:
        - The REG10 sequence is played for 3 seconds (6 repetitions).
        - The RAND20 sequence follows for 3 seconds (3 repetitions).

  3. Task Structure 
    A. Initial Fixation Phase: a black fixation cross is presented at the center of a grey screen for 5 seconds before the trials begin.
    B. Trial Structure
      1. Inter Stimulus Interval (ISI) (2s):
        - a grey screen with black fixation cross is displayed for 2 seconds before the sequence begins 
      2. Stimulus Phase (6s)
        - one of the conditions is randomly chosen and played
        - throughout this phase, a grey screen with a black fixation cross remains displayed.
    C. Trial Numbers
      1. Control trials: 5 per Condition, total 10
      2. Transition Trials: 10 per Condition, total 30

