""" print(sound.Sound)

from pprint import pprint
import psychtoolbox.audio
pprint(psychtoolbox.audio.get_devices()) """

from psychopy import prefs, core
prefs.hardware['audioLib'] = 'ptb' #PTB described as highest accuracy sound class
prefs.hardware['audioDevice'] = 'Kopfhörer (HyperX Virtual Surround Sound)' # define audio device
prefs.hardware['audioLatencyMode'] = 3
from psychopy import sound
import psychtoolbox as ptb #sound processing via ptb

print(prefs.hardware)

""" mySound = sound.Sound('A', stereo=True)
now = ptb.GetSecs()
mySound.play(when=now+0.5)  # play in EXACTLY 0.5s """


standard_sound = sound.Sound(750, stereo=True, secs=5, volume=1)
print(standard_sound)
standard_sound.play()
core.wait(1.0)
standard_sound.stop()