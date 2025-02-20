import subprocess
import time
import logging
from psychopy import gui, core
from datetime import datetime
import os
from pathlib import Path

venv_python = Path("C:/Users/iskra_todorova/PowerFolders/CodeTests/venv310/Scripts/python.exe").resolve()


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
logging.basicConfig(level=logging.INFO, filename="experiment_log.txt", filemode="w",
                    format="%(asctime)s - %(levelname)s - %(message)s")

# Create a dialog box for participant info
exp_info = {
    "Participant ID": "",
    "Timepoint": ["test", "pilot", "T1", "T2", "T3"]
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
timepoint = exp_info["Timepoint"][0]

logging.info(f"Participant ID: {participant_id}")
logging.info(f"Timepoint: {timepoint}")

# List of tasks to run in sequence
tasks = [
    "visual_oddball.py",
    "cued-visual-search-animation.py",
    "auditory_oddball.py",
    "rapid-sound-sequences.py"
]

def run_task(task_name):
    logging.info(f"Starting task: {task_name}")
    print(f"Running {task_name}...")  
    
    # Run the Python script using the virtual environment's Python
    subprocess.run([str(venv_python), task_name, participant_id, timepoint])  

    logging.info(f"Finished task: {task_name}")
    
    # Pause between tasks
    print("Pausing for 10 seconds before the next task...\n")
    time.sleep(10)

# Run all tasks sequentially
for task in tasks:
    run_task(task)

print("All tasks completed!")
logging.info("All tasks completed.")

