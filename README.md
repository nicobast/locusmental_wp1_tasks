# Tasks LOCUS-MENTAL

## Overview 
This study consists of four tasks:
* an passive auditory Oddball Task (auditory_oddball.py)
* an active visual Oddball Task (visual_oddball.py)
* regularity in rapid sound sequences - WORK IN PROGRESS
* cued visual search - WORK IN PROGRESS

During all tasks, pupil dilation is measured via eye tracking and parallel port triggers are sent to an EEG recording PC. Several baseline phases are used to determine tonic pupil size. 

## Installation Guide for Python and Required Modules
# Python Installation
* The required Python module tobii-research is compatible only with Python 3.10. Therefore, ensure you install Python 3.10 according to your system requirements or create a virtual environment that uses Python 3.10.
* Do not download Python from the Microsoft Store, as it is treated as an app, which can cause conflicts. Instead, download Python directly from the official website: https://www.python.org/downloads/windows/.
  * When running the installer (.exe file):
      1. Run it as Administrator.
      2. Check the box "Add PYTHON to PATH" to automatically set the environment variable, avoiding manual setup.
# Working with Multiple Python Versions
* If you have multiple Python versions installed, you can create a virtual environment specifically for Python 3.10:
  * Check the Python version available: python --version
  * Create a virtual environment using Python 3.10: python3.10 -m venv environment_name
  * Activate the virtual environment: environment_name\Scripts\activate
# Installing Required Modules
 * you use a virtual environment, all modules must be installed within that environment:
  1. Psychopy: Install version 2023.1.3, as newer versions may not be compatible : pip install psychopy==2023.1.3
  2. NumPy: Install version 1.23.5: pip install numpy==1.23.5
  3. Verify all installed modules using: pip list
  4. additional modules required by the script (e.g., sounddevice or ptb) are missing, install them as well: pip install module_name
# Running Animations
To run animation files, you need the module Manim. For better compatibility, it is recommended to use a separate virtual environment with a newer Python version (e.g., Python 3.11). Avoid installing Manim and Psychopy in the same environment due to dependency conflicts.

## Install instructions
NOTE: inpout32.dll file is required in experiment folder (driver file) to send parallel port triggers

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

## Parallel port
send parallel port trigger: https://psychopy.org/api/parallel.html -> send trigger -> C:\Users\stimulation\AppData\Local\Programs\PsychoPy\python.exe C:\Users\stimulation\Desktop\project_py_oddball_280322\test_parallelport.py -> see: https://stackoverflow.com/questions/26762015/psychopy-sending-triggers-on-64bit-os/26889541#26889541 -> see also: https://osdoc.cogsci.nl/3.3/manual/devices/parallel/#windows-7-32-and-64-bit.

*port = parallel.ParallelPort(0x03FF8)*
**Don't quote this setting!** <br/>The correct port needs to be identified (use standalone "Parallel Port Tester programm" -> set all pins to low -> port.setData(0))

## Eye tracking
* difference to psychopy documentation required: Define name as tracker and define a presentation window before.
* in case testmode = True: the mouse is used as eyetracker and data stored in hdf5 file: -> import h5py -> access data: dset1 = f['data_collection/events/eyetracker/MonocularEyeSampleEvent']

## The Auditory Oddball Task
The task is used to manipulate Locus-Coeruleus-Norepinephrine (LC-NE) activity. In four task blocks, each including 100 trials, a frequent tone (standard) is presented with a probability of 80% while an infrequent tone of a different pitch (oddball) is presented with a probability of 20%. The pitch level indicating oddballs in the 1st task block and the 3rd task block (oddball blocks) are either 500 Hz or 750 Hz. Oddballs in the 2nd and 4th task block are of the opposite pitch (oddball blocks reverse). Three additional standard trials precede each task block.  

### Task sequence
1. intro slide
2. baseline calibration
3. oddball block
4. baseline phase
7. outro slide

## The Visual Oddball Task
The task is used and to observe effects of task utility and stimulus salience. It contains independent manipulations of both. In four task blocks, each including 150 trials, a frequent purple circle is presented with a probability of 80% while an infrequent smaller purple circle (oddball) is presented with a probability of 20%. As in the Auditory Oddball task, three additional standard trials precede each task block. The task starts with four separate practice blocks, each containing of 13 trials, as a familiarisation. In the end, the test subjcet receives feedback aboout their winnings. 

### Task sequence
1. instruction slide 1
2. baseline calibration
3. instruction slide 2
4. instruction slide practice trials
5. baseline phase
6. practice block 1
7. baseline phase
8. practice block 2
9. baseline phase
10. practice block 3
11. baseline phase
12. practice block 4
13. instruction slide 3
14. baseline phase
15. oddball block 1
16. baseline phase
17. oddball block 2
17. baseline phase
18. oddball block 3
19. baseline phase
20. oddball block 4
21. reward feedback
22. instruction slide 4

### Automatic conversion of visual angle to pixels in script
* *size_fixation_cross_in_pixels = 132*, also defines standard stimulus size and translates to 3.2 degrees visual angle on 24 inch screen with 25.59 inches screen distance (see https://elvers.us/perception/visualAngle/)
* *high_salience_ball_size = round(0.5 * size_fixation_cross_in_pixels)* translates to 1.6 degrees visual angle on 24 inch screen with 25.59 inches screen distance.
* *low_salience_ball_size = round(0.91 * size_fixation_cross_in_pixels)* translates to 2.9 degrees visual angle on 24 inch screen with 25.59 inches screen distance.


## Cued Visual Search Task
# Two Versions Available
  * cued-visual-search-cross.py - fixation cross as inter stimulus
  * cued-visual-search-animation.py - animations as inter stimulus

# For the Animations
  * The animations are pre-rendered and stored in the project directory: .\Media\Videos\1080x60.
  * You need to either download the animations or clone them with the repository.
* If you want to render the animations from the animation-cued-visual-search.py script:
  * The rendered videos will be stored in the same location (.\Media\Videos\1080p60).
  * After rendering, select the videos you want to use and rename them sequentially from 1 to 21, otherwise you need to adjust the code in the task

# Before running the task
  * Create folders in your project directory if not existing data\cued_visual_search\logging_data
  * Set resolution to fit your monitor
  * Use 'escape' to abrupt the task