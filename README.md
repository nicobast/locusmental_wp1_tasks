# Tasks LOCUS-MENTAL

## Overview 
This study consists of four tasks:
* an passive auditory Oddball Task (auditory_oddball.py)
* an active visual Oddball Task (visual_oddball.py)
* regularity in rapid sound sequences - WORK IN PROGRESS
* cued visual search - WORK IN PROGRESS

During all tasks, pupil dilation is measured via eye tracking and parallel port triggers are sent to an EEG recording PC. Several baseline phases are used to determine tonic pupil size. 

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
  * Create a virtual environment using Python 3.10: python3.10 -m venv environment_name
  * Activate the virtual environment: environment_name\Scripts\activate
## Installing Required Modules
 * Installation requires "Microsoft Visual C++ 14.0" bundled with "Microsoft C++ Build Tools" (Desktop Development with C++).
 * you use a virtual environment, all modules must be installed within that activate environment:
  1. Psychopy: Install version 2023.1.3, as newer versions may not be compatible : pip install psychopy==2023.1.3
  2. NumPy: Install version 1.23.5: pip install numpy==1.23.5
  3. Tobii Pro SDK as Tobii Research Python module: pip install tobii_research
  4. Verify installation of Psychopy and Numpy using: pip list
  5. additional modules required by the script (e.g., sounddevice or ptb) are missing, install them as well: pip install module_name
## Running Animations
To run animation files, you need the module Manim. For better compatibility, it is recommended to use a separate virtual environment with a newer Python version (e.g., Python 3.11). Avoid installing Manim and Psychopy in the same environment due to dependency conflicts.

## Submodule iohub
 * Issue: during task execution, an error in one of the module files occured prevented the recording of gaze data.
  - ERROR: KeyError: 'right_gaze_origin_in_trackbox_coordinate_system'
  - Problem Background: The KeyError occurs because the code attempts to access a non-existing key 'right_gaze_origin_in_trackbox_coordinate_system', in the gaze data returned by the Tobii eye tracker. In the tobii-research module, the correct keys are: 'right_gaze_origin_in_user_coordinate_system' instead.
  - Solution: 
    1.  Locate the following file in your Python environment: <Python Environment Directory>lib\site-packages\psychopy\iohub\devices\eyetracker\hw\tobii\eyetracker.py
    2.  Find lines 432 and 433 and replace them with the following corrected code:
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
Monitor parameters are adapted to the presentation PC. The name is saved with psychopy monitor manager. Please note:
* avoid integrated graphics for experiment computers wherever possible as no accurate frame timing
* set Windows scaling to 100% - otherwise onscreen units will not get right
* experiment screen will be FUllHD, thus testscreen is specified accordingly
* Screen resolution is 1920/1080.

## Eye tracking
* difference to psychopy documentation required: Define name as tracker and define a presentation window before.
* in case testmode = True: the mouse is used as eyetracker and data stored in hdf5 file: -> import h5py -> access data: dset1 = f['data_collection/events/eyetracker/MonocularEyeSampleEvent']

## The Auditory Oddball Task
The task is used to manipulate Locus-Coeruleus-Norepinephrine (LC-NE) activity. In four task blocks, each including 100 trials, a frequent tone (standard) is presented with a probability of 80% while an infrequent tone of a different pitch (oddball) is presented with a probability of 20%. The pitch level indicating oddballs in the 1st task block and the 3rd task block (oddball blocks) are either 500 Hz or 750 Hz. Oddballs in the 2nd and 4th task block are of the opposite pitch (oddball blocks reverse). Three additional standard trials precede each task block.  

### Task sequence
1. baseline calibration
2. oddball block
3. baseline phase

## The Visual Oddball Task
The task is used and to observe effects of task utility and stimulus salience. It contains independent manipulations of both. In four task blocks, each including 150 trials, a frequent purple circle is presented with a probability of 80% while an infrequent smaller purple circle (oddball) is presented with a probability of 20%. As in the Auditory Oddball task, three additional standard trials precede each task block. The task starts with four separate practice blocks, each containing of 13 trials, as a familiarisation. In the end, the test subjcet receives feedback aboout their winnings. 


### Automatic conversion of visual angle to pixels in script
* *size_fixation_cross_in_pixels = 132*, also defines standard stimulus size and translates to 3.2 degrees visual angle on 24 inch screen with 25.59 inches screen distance (see https://elvers.us/perception/visualAngle/)
* *high_salience_ball_size = round(0.5 * size_fixation_cross_in_pixels)* translates to 1.6 degrees visual angle on 24 inch screen with 25.59 inches screen distance.
* *low_salience_ball_size = round(0.91 * size_fixation_cross_in_pixels)* translates to 2.9 degrees visual angle on 24 inch screen with 25.59 inches screen distance.


# Cued Visual Search Task
## Two Versions Available
  * cued-visual-search-cross.py - fixation cross as inter stimulus, curently no eye-tracking
  * cued-visual-search-animation.py - animations as inter stimulus, currently adapted to record eye-tracking data

## For the Animations
  * The animations are pre-rendered and stored in the project directory: .\Media\Videos\1080x60.
  * You need to either download the animations or clone them with the repository.
* If you want to render the animations from the animation-cued-visual-search.py script:
  * The rendered videos will be stored in the same location (.\Media\Videos\1080p60).
  * After rendering, select the videos you want to use and rename them sequentially from 1 to 21, otherwise you need to adjust the code in the task

## Before running the task
  * Create folders in your project directory if not existing data\cued_visual_search\logging_data
  * Set resolution to fit your monitor
  * Use 'escape' to abrupt the task


# Rapid Sound Sequences
 * File: rapid-sound-sequences.py
 
## Task Description
  * the task is designed to present a series of auditory stimuli (tones of varying frequencies) in rapid succession.The task includes four conditions: two control conditions (regular and irregular sequences) and two transition conditions (from regular to irregular and from irregular to regular).
  
  * Control Conditions:
  Regular: Sounds presented in a predictable, repeating pattern.
  Irregular: Sounds presented in a randomized pattern.
  * Transition Conditions:
  Regular-to-Irregular: Sequence transitions from regular to irregular patterns.
  Irregular-to-Regular: Sequence transitions from irregular to regular patterns.