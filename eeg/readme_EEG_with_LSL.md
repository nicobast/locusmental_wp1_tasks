README - integrate EEG to battery



\#INSTALLATION



* baseline: current state of Git Hub repository as base (see June pushes)

 	- commit  c253560dfe65311496a42b502d36f01d377fffce (HEAD -> master)

* install Brain Vision LSL Connector

 	- pushes EEG stream from LiveAmp amplifier to LSL

 	- also allows to check impedances (potentially totally bypass BrainVision Recorder)

* install pylsl via "pip install pylsl" to virtual environment that contains psychopy

 	- LSL functionality in Python

 	- allows to send LSL triggers from within Psychopy

* install LabRecorder - takes EEG stream (LSL connector) and psychopy triggers (pylsl) and saves to file (XDF format)

 	- a config file that can be loaded is provided with the git repo

* **optional for data analysis**: created additional virtual environment (venv\_eeg)

 	- installed pyxdf that reads XDF file as pyxdf is not compatible with current battery virtual environment that requires numpy<2.0

 	- installed pandas to convert xdf to csv for reading in R

 	- installed BrainVision LSL Viewer to monitor EEG data



\#HOW TO



* start BrainVIsion LSL Connector

 	- setup EEG R-NET cap with correct size (TODO: record cap size)

 	- check impedances

 	- --> LINK to push EEG LSL stream

* start Lab Recorder

 	- load config file provided with repo that has correct naming conventions and marker streams

&nbsp;	- these streams can be in RED and will be later picked up by the LabRecorder

 	- start recording

* start battery runner.py until dlg box





\#COMMENTS



* currently implemented in auditory\_oddball --> implement to other tasks
* reduced number of trials
* config file for labRecorder needs to be setup on recording PC
* test with TX300 eye tracking
* test with caps
