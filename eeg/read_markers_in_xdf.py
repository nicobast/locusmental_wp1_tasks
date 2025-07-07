import pyxdf
from collections import Counter
import sys

def main(xdf_path):
    # Load your .xdf file
    data, header = pyxdf.load_xdf(xdf_path)

    #data summary
    for stream in data:
        print(f"Stream: {stream['info']['name'][0]}")
        print(f"Samples: {len(stream['time_series'])}")

    #data structure
    print("Number of streams:", len(data))
    for i, stream in enumerate(data):
        print(f"\nStream {i}:")
        for key in stream.keys():
            print(f"  {key}: type={type(stream[key])}")
            # For nested dictionaries, print their keys too
            if isinstance(stream[key], dict):
                for subkey in stream[key].keys():
                    print(f"    {subkey}: type={type(stream[key][subkey])}")


    # Find the marker stream
    marker_stream = next((s for s in data if s['info']['type'][0] == 'Markers'), None)

    if marker_stream:
        markers = [m[0] for m in marker_stream['time_series']]
        timestamps = marker_stream['time_stamps']

        # Count occurrences
        counts = Counter(markers)
        print("Trigger Summary:")
        for marker, count in counts.items():
            print(f"{marker}: {count} occurrence(s)")

        # Show sample timestamps
        print("\nSample Timestamps:")
        for marker in counts:
            times = [timestamps[i] for i, m in enumerate(markers) if m == marker]
            print(f"{marker}: {times[:3]} ...")
    else:
        print("No marker stream found.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python read_markers_in_xdf.py <path_to_xdf_file>")
    else:
        main(sys.argv[1])
