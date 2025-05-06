# Set preferences early
from psychopy import prefs
# Default to sounddevice for the runner itself
prefs.hardware['audioLib'] = ['sounddevice', 'pyo', 'pygame']
prefs.hardware['audioLatencyMode'] = 3  # Aggressive timing
prefs.saveUserPrefs()

# System and environment settings
import os
os.environ['PYTHONUNBUFFERED'] = '1'  # Helps with audio stability

# Imports (after prefs)
import subprocess
import logging
import platform
from psychopy import gui, core, visual, event, monitors, sound
from datetime import datetime
from pathlib import Path
import json
import random
import sys
import time
import gc

# Record session start time
battery_start_time = core.getTime()

# Load config
try:
    with open("tasks/original_version/config.json", "r") as file:
        config = json.load(file)
except FileNotFoundError:
    print("Config file not found. Please check the path.")
    sys.exit(1)

venv_python = Path(config["python_env"]["venv_path"]).resolve()
task_paths = config["task_paths"]

# Logging setup
current_datetime = datetime.now()
formatted_datetime = current_datetime.strftime("%Y-%m-%d_%H-%M-%S")
logging_path = Path("data", "runner", "logging_data").resolve()
filename_runner = os.path.join(logging_path, f"battery_log_{formatted_datetime}.txt")

if not logging_path.exists():
    logging_path.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    filename=filename_runner,
    filemode="w",
    format="%(asctime)s - %(levelname)s - %(message)s"
)

system_info = {
    "OS": platform.system(),
    "OS Version": platform.version(),
    "Python Version": platform.python_version(),
    "Virtual Environment Path": str(venv_python)
}
logging.info(f"System Info: {system_info}")

# Participant dialog
exp_info = {
    "Participant ID": "",
    "Timepoint": ["Test", "Pilot", "T1", "T2", "T3"]
}

dlg = gui.DlgFromDict(dictionary=exp_info, title="Experiment Session")
if not dlg.OK:
    logging.warning("Experiment cancelled.")
    core.quit()

participant_id = exp_info["Participant ID"]
timepoint = exp_info["Timepoint"]
logging.info(f"Participant: {participant_id}, Timepoint: {timepoint}")

# Define tasks
tasks = [
    "auditory_oddball",
    "cued_visual_search",
    "rapid_sound_sequences",
    "visual_oddball"
]

# Monitor and window setup
# Get monitor settings from config
monitor_config = config['constants']['monitor']
psychopy_window_config = config['constants']['psychopy_window']

# Set up monitor
try:
    my_monitor = monitors.Monitor(monitor_config['name'])
    my_monitor.setSizePix([monitor_config['width'], monitor_config['height']])
    my_monitor.setDistance(monitor_config['distance_cm'])
    my_monitor.setWidth(monitor_config['width_cm'])
except Exception as e:
    print(f"Error setting up monitor, using defaults: {e}")
    my_monitor = monitors.Monitor("testMonitor")
    my_monitor.setSizePix([2560, 1440])  # Fallback values

def create_window():
    """Create a fresh window using config settings"""
    win = visual.Window(
        size=[monitor_config['width'], monitor_config['height']],
        fullscr=psychopy_window_config['fullscreen'],
        monitor=my_monitor,
        color=psychopy_window_config['background_color'],
        units='pix',
        screen=config['constants']['presentation_screen']
    )
    return win

def reset_audio():
    """Safely reset audio systems"""
    # Close PTB audio if used
    try:
        from psychtoolbox import audio
        try:
            audio.PsychPortAudio('Close', -1)  # Close all devices
        except Exception as e:
            if 'pamaster' not in str(e).lower():
                logging.debug(f"PTB audio close error: {e}")
    except ImportError:
        pass
    
    # Shutdown PsychoPy sound
    try:
        sound.backend.shutdown()
    except Exception as e:
        logging.debug(f"Sound backend shutdown: {e}")
    
    # Wait a moment to ensure audio systems reset
    time.sleep(0.5)

def force_cleanup():
    """Force garbage collection and memory cleanup"""
    try:
        # Run garbage collection several times to clean up
        for _ in range(3):
            gc.collect()
            time.sleep(0.1)
    except Exception as e:
        logging.debug(f"GC error: {e}")

def set_task_audio():
    """Configure audio for tasks"""
    reset_audio()
    
    from psychopy import prefs
    prefs.hardware['audioLib'] = ['ptb', 'sounddevice', 'pyo']
    prefs.saveUserPrefs()
    
    # Wait for audio to initialize
    time.sleep(0.5)
    
    logging.info("Set audio backend for tasks (PTB)")

def play_video_external(video_path):
    """Play a video using an external player (VLC or system default)"""
    logging.info(f"Playing video with external player: {Path(video_path).name}")
    print(f"Starting video playback: {Path(video_path).name}")
    
    # First try VLC if available (better control)
    success = False
    
    # Check if we're on Windows
    if platform.system() == "Windows":
        # Common paths for VLC on Windows
        vlc_paths = [
            r"C:\Program Files\VideoLAN\VLC\vlc.exe",
            r"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe",
        ]
        
        # Try to find VLC
        vlc_path = None
        for path in vlc_paths:
            if os.path.exists(path):
                vlc_path = path
                break
        
        if vlc_path:
            try:
                # Play with VLC in fullscreen mode, close when done
                subprocess.run([
                    vlc_path,
                    "--play-and-exit",
                    "--fullscreen",
                    "--no-video-title-show",
                    str(video_path)
                ], check=True)
                success = True
                logging.info("Video played successfully with VLC")
                print("Video played successfully with VLC")
            except Exception as e:
                logging.error(f"Error playing with VLC: {e}")
                print(f"Error playing video with VLC: {e}")
                success = False
    
    # If VLC didn't work, try system default
    if not success:
        try:
            if platform.system() == "Windows":
                os.startfile(str(video_path))
            elif platform.system() == "Darwin":  # macOS
                subprocess.run(["open", str(video_path)], check=True)
            else:  # Linux
                subprocess.run(["xdg-open", str(video_path)], check=True)
            
            # Give the video time to play - approx length of videos
            time.sleep(30)  # Adjust based on your video length
            success = True
            logging.info("Video played with system default player")
            print("Video played with system default player")
        except Exception as e:
            logging.error(f"Error playing with system player: {e}")
            print(f"Error playing video with system player: {e}")
    
    # Log completion
    if success:
        print("Video playback complete. Continuing with the next task...")
    else:
        print("Unable to play video. Continuing with the next task...")
    
    # Force cleanup and reset
    force_cleanup()

# Alternative video playback using Python's subprocess to run ffplay
def play_video_ffplay(video_path):
    """Play video using FFplay (from FFmpeg)"""
    logging.info(f"Playing video with FFplay: {Path(video_path).name}")
    print(f"Attempting to play video with FFplay: {Path(video_path).name}")
    
    # Check if FFplay/FFmpeg is installed
    ffplay_cmd = None
    try:
        # Check for ffplay in path
        subprocess.run(["ffplay", "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        ffplay_cmd = "ffplay"
    except:
        # Look for common FFmpeg installation locations on Windows
        ffmpeg_paths = [
            r"C:\Program Files\ffmpeg\bin\ffplay.exe",
            r"C:\ffmpeg\bin\ffplay.exe",
        ]
        
        for path in ffmpeg_paths:
            if os.path.exists(path):
                ffplay_cmd = path
                break
    
    if ffplay_cmd:
        try:
            # Use ffplay for reliable playback
            subprocess.run([
                ffplay_cmd,
                "-autoexit",          # Exit when the video ends
                "-fs",                # Fullscreen
                "-loglevel", "quiet", # Suppress normal output 
                "-stats",             # Show playback stats
                "-x", "1280",         # Width
                "-y", "720",          # Height
                str(video_path)       # Video path
            ], check=True)
            
            logging.info("Video played successfully with FFplay")
            print("Video played successfully with FFplay")
            return True
        except Exception as e:
            logging.error(f"Error playing with FFplay: {e}")
            print(f"Error playing video with FFplay: {e}")
            return False
    else:
        logging.warning("FFplay not found, falling back to system player")
        print("FFplay not found, falling back to system player")
        return False

# Load video files
media_folder = Path("media/between_tasks_videos").resolve()
video_files = list(media_folder.glob("*.mp4"))
if not video_files:
    logging.warning("No videos found in between_tasks_videos folder.")
else:
    logging.info(f"Found {len(video_files)} between-task videos.")

# Create a file with PTB audio settings
def create_temp_ptb_settings():
    """Create a temporary python file with PTB audio settings"""
    tmp_file = Path("temp_ptb_settings.py")
    with open(tmp_file, "w") as f:
        f.write("""
# Temporary PTB audio settings
from psychopy import prefs
prefs.hardware['audioLib'] = ['ptb', 'sounddevice', 'pyo']
prefs.saveUserPrefs()
print("PTB audio settings applied.")
""")
    return tmp_file

# Run a single task
def run_task(task_name, task_path):
    task_start_time = core.getTime()
    logging.info(f"Starting task: {task_name}")
    print(f"Running {task_name}...")

    # Force cleanup before task
    force_cleanup()
    
    # Set audio for task
    set_task_audio()
    
    # Create temp PTB settings file
    temp_settings = create_temp_ptb_settings()
    
    # Environment variables
    env = os.environ.copy()
    env["PSYCHOPY_AUDIO_PTB_DEBUG"] = "1"  # Enable PTB audio debugging
    
    task_script = Path(config["task_base_path"]) / task_path
    
    # Run the task
    try:
        # Apply PTB settings first
        pre_cmd = f"{str(venv_python)} {str(temp_settings)}"
        subprocess.run(pre_cmd, shell=True, env=env, check=True)
        
        # Run task
        cmd = f"{str(venv_python)} {str(task_script)} {participant_id} {timepoint}"
        subprocess.run(cmd, shell=True, env=env, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Task {task_name} failed with code {e.returncode}")
    except Exception as e:
        logging.error(f"Task {task_name} error: {e}")
    
    # Cleanup
    if temp_settings.exists():
        temp_settings.unlink()
    
    # Reset audio after task
    reset_audio()
    force_cleanup()

    task_end_time = core.getTime()
    duration = task_end_time - task_start_time
    logging.info(f"Finished {task_name}: {duration:.2f} sec ({duration / 60:.2f} min)")

# --- MAIN LOOP ---
if __name__ == "__main__":
    try:
        # Initial audio setup
        set_task_audio()
        
        # Process tasks
        for idx, task_name in enumerate(tasks):
            if task_name in task_paths:
                task_script = task_paths[task_name]
                
                # Run the task
                run_task(task_name, task_script)

                # Show video between tasks (not after last task)
                if idx < len(tasks) - 1 and video_files:
                    # Select a random video
                    selected_video = random.choice(video_files)
                    
                    # Try FFplay first, then fall back to external player
                    if not play_video_ffplay(str(selected_video)):
                        play_video_external(str(selected_video))
            else:
                logging.warning(f"Task {task_name} not found in config.")

        # Print completion message to console instead of showing to participant
        print("\nAll tasks complete! Thank you for participating.")

        # Battery complete
        battery_end_time = core.getTime()
        total_duration = battery_end_time - battery_start_time
        logging.info(f"Total battery duration: {total_duration:.3f} sec")
        print(f"\nAll tasks complete! Total duration: {total_duration/60:.2f} minutes")
        
    except Exception as e:
        logging.error(f"Battery execution error: {e}", exc_info=True)
    finally:
        # Final cleanup
        reset_audio()
        force_cleanup()
        core.quit()