import subprocess
import time
import logging
import platform
from psychopy import gui, core
from datetime import datetime
import os
from pathlib import Path
import json

#Record the start time of the session
battery_start_time = core.getTime()

# Load configuration
with open("config.json", "r") as file:
    config = json.load(file)

venv_python = Path(config["python_env"]["venv_path"]).resolve()
task_paths = config["task_paths"]

# Setup logging:
current_datetime = datetime.now()
formatted_datetime = str(current_datetime.strftime("%Y-%m-%d %H-%M-%S"))
logging_path = Path( "data", "runner", "logging_data").resolve()
filename_runner = os.path.join(logging_path, formatted_datetime)

# Check if the directory exists
if not logging_path.exists():
    # If it doesn't exist, create it
    logging_path.mkdir(parents=True, exist_ok=True)
else:
    print(f"Directory {logging_path} already exists. Continuing to use it.")

# Set up logging
logging.basicConfig(level=logging.INFO, filename=filename_runner, filemode="w",
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Log system information
system_info = {
    "OS": platform.system(),
    "OS Version": platform.version(),
    "Python Version": platform.python_version(),
    "Virtual Environment Path": str(venv_python)
}
logging.info(f"System Information: {system_info}")

# Create a dialog box for participant info
exp_info = {
    "Participant ID": "",
    "Timepoint": ["Test", "Pilot", "T1", "T2", "T3"]
}

dlg = gui.DlgFromDict(
    dictionary=exp_info,
    title="Experiment Session",
    order=["Participant ID", "Timepoint"]
)

if not dlg.OK:
    logging.warning("Experiment canceled by the user.")
    core.quit()

participant_id = exp_info["Participant ID"]
timepoint = exp_info["Timepoint"]

logging.info(f"Participant ID: {participant_id}")
logging.info(f"Timepoint: {timepoint}")

# List of tasks to run in sequence
tasks = [
    "auditory_oddball",
    "cued_visual_search",
    "rapid_sound_sequences",
    "visual_oddball"
]

def run_task(task_name, task_path):
    task_start_time = core.getTime()
    logging.info(f"Starting task: {task_name}")
    print(f"Running {task_name}...")

    try:   
        subprocess.run([str(venv_python), str(task_path), participant_id, timepoint], check= True)
    except subprocess.CalledProcessError as e:
        logging.warning(f"Task {task_name} may not have completed properly - {str(e)}")
    
    task_end_time = core.getTime()  # End time for individual task
    task_duration = task_end_time - task_start_time

    logging.info(f"Finished task: {task_name} (Duration: {task_duration:.3f} seconds)")

    print("Pausing for 10 seconds before the next task...\n")
    time.sleep(10)

# Run all tasks correctly
for task_name in tasks:  # Run only selected tasks in this order
    if task_name in task_paths:
        run_task(task_name, task_paths[task_name])
    else:
        logging.warning(f"Task {task_name} not found in config.") 
        
# Calculate total battery duration
battery_end_time = core.getTime()
total_duration = battery_end_time - battery_start_time
logging.info(f"Total battery duration: {total_duration:.3f} seconds")
print(f"\nTotal battery duration: {total_duration:.3f} seconds")

print("All tasks completed!")
logging.info("All tasks completed.")

