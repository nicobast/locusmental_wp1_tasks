from pylsl import StreamInfo, StreamOutlet
from psychopy import visual, core, event

# Create LSL marker stream - that is able to send trigger
info = StreamInfo(name='Markers', type='Markers', channel_count=3,
                  nominal_srate=0, channel_format='string', source_id='stimulus_stream')
outlet = StreamOutlet(info)

# Create a simple PsychoPy window
win = visual.Window(size=(800, 600), color='black')
text = visual.TextStim(win, text='Sending triggers...', color='white')

# Show message and send triggers
text.draw()
win.flip()

#wait for keypress
print("wait for keypress before sending triggers...")
event.waitKeys()


for i in range(10):
    marker = f"Stimulus/S{i+1}"
    #outlet.push_sample([marker])
    outlet.push_sample([marker, 'test', str(i)])
    print([" ".join([marker,"sent sucessfully"])])
    core.wait(1)

# Close the window and quit PsychoPy
text.text = 'Triggers sent. Closing...'
win.close()
core.quit()
