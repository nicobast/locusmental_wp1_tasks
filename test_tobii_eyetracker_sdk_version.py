import tobii_research as tr
import time

found_eyetrackers = tr.find_all_eyetrackers()
my_eyetracker = found_eyetrackers[0]

print("Address: " + my_eyetracker.address)
print("Model: " + my_eyetracker.model)
print("Name (It's OK if this is empty): " + my_eyetracker.device_name)
print("Serial number: " + my_eyetracker.serial_number)

def gaze_position(gaze_data):
    
    left_gaze = gaze_data['left_gaze_point_on_display_area']
    right_gaze = gaze_data['right_gaze_point_on_display_area']

    #check whether valid data avaialable
    if gaze_data['left_gaze_point_validity'] == gaze_data['right_gaze_point_validity'] == 0:
        gaze_point = None
    elif gaze_data['left_gaze_point_validity'] == gaze_data['right_gaze_point_validity'] == 1:
        gaze_point = [(right_gaze[0] + left_gaze[0]) / 2.0, (right_gaze[1] + left_gaze[1]) / 2.0]
    elif gaze_data['left_gaze_point_validity'] == 1:
        gaze_point = [left_gaze[0], left_gaze[1]]
    elif gaze_data['right_gaze_point_validity'] == 1:
        gaze_point = [right_gaze[0], right_gaze[1]]

    #center
    #convert to pixels

    print(str(gaze_point))

    return(gaze_point)


def getList(dict):
    list(dict.keys())
    print(getList(dict))


current_position = my_eyetracker.subscribe_to(tr.EYETRACKER_GAZE_DATA, gaze_position, as_dictionary=True)
time.sleep(5)
print('this is the last position: ' + current_position[0] + '_' + current_position[1])

my_eyetracker.unsubscribe_from(tr.EYETRACKER_GAZE_DATA, gaze_position)
