
import pyxdf
import pandas as pd
import os

# Load the XDF file
xdf_file = 'C:/Users/nico/PowerFolders/project_locusmental_wp1/eeg/data/test_trigger4_T1_04072025.xdf' # Replace with your actual file path
data, header = pyxdf.load_xdf(xdf_file)

#get file name without extension
file_name = os.path.splitext(os.path.basename(xdf_file))[0]

# Create output directory
output_dir = "eeg/data/xdf_to_csv_output"
os.makedirs(output_dir, exist_ok=True)

# Process each stream
for idx, stream in enumerate(data):
    stream_name = stream['info']['name'][0]
    stream_type = stream['info']['type'][0]
    timestamps = stream['time_stamps']
    values = stream['time_series']

    # Create a DataFrame
    df = pd.DataFrame(values)
    df.insert(0, "Timestamp", timestamps)

    # Make a safe filename
    safe_name = "".join([c if c.isalnum() else "_" for c in stream_name])
    safe_type = "".join([c if c.isalnum() else "_" for c in stream_type])
    csv_filename = f"{file_name}_{safe_name}_{safe_type}_{idx}.csv"
    csv_path = os.path.join(output_dir, csv_filename)
    df.to_csv(csv_path, index=False)

    print(f"Saved stream '{stream_name}' of type '{stream_type}' to {csv_path}")

# Print completion message
print("All streams have been converted to CSV files.")
