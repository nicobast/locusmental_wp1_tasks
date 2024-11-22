#import psychopy
#psychopy.useVersion('2021.2') #use a specific version of psychopy

from psychopy.iohub import launchHubServer
from psychopy.core import getTime, wait

from psychopy import visual, monitors

#define monitor
mon = monitors.Monitor(
    name = 'LGcenter_nico_workstation',
    width = 71,
    distance = 60)

# Create display window.
mywin = visual.Window(size=[3840,2160],
                      #pos=[0,0],
                      fullscr=True,
                      monitor=mon,
                      color = [0, 0, 0],
                      screen=0, #0 = primary screen
                      units="pix") #unit changed to pixel so that eye tracker outputs pixel on presentation screen


import tobii_research

found_eyetrackers = tobii_research.find_all_eyetrackers()

while found_eyetrackers == []:
    wait(0.5)
    found_eyetrackers = tobii_research.find_all_eyetrackers()

my_eyetracker = found_eyetrackers[0]
print("Address: " + my_eyetracker.address)
print("Model: " + my_eyetracker.model)
print("Name (It's OK if this is empty): " + my_eyetracker.device_name)
print("Serial number: " + my_eyetracker.serial_number)

#deifne a config that allow iohub to connect to the eye-tracker
iohub_config = {'eyetracker.hw.tobii.EyeTracker':
    {'name': 'tracker', 'runtime_settings': {'sampling_rate': 60, }}}

#TODO: need to define sesssion_code so data is saved as hdf5
io = launchHubServer(**iohub_config,
                        window = mywin) #creates a separate instance that records eye tracking data outside loop

# Get the eye tracker device.
tracker = io.devices.tracker

# run eyetracker calibration --> do it in EyeTrackerManager by Tobii
# calibration_data = tracker.runSetupProcedure()
#save calibration_data somewhere

#start recording
tracker.setRecordingState(True)

# #print all events
# stime = getTime()
# while getTime()-stime < 2.0:
#     for e in tracker.getEvents():
#         print(e)

#draw rect
background_rect = visual.Rect(win=mywin, size=mywin.size, fillColor= [1,0,0], colorSpace = 'rgb', autoDraw=True)



# Check for and print current eye position every 100 msec.
stime = getTime()
while getTime()-stime < 10:
    print(tracker.getPosition())
    print(tracker.trackerTime()) #eyetracker time --> insert in expriment loop
    
    print(tracker.getLastSample())

    #draw rect
    background_rect.draw()

    wait(0.1)

tracker.setRecordingState(False)

io.quit()