import numpy as np
import glob
import os
import pathlib


def npz_to_csv_with_format(file_path, output_dir):
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Load the data from the .npz file
    data = np.load(file_path)

    # Extract x and y arrays
    x = data['X']
    y = data['y']

    # Ensure y is reshaped as a column vector if needed
    if y.ndim == 1:
        y = y.reshape(-1, 1)

    # Concatenate x and y along the last axis
    combined = np.concatenate((x, y), axis=1)

    # Define the format for each column: float format for x, integer format for y
    num_x_columns = x.shape[1] if x.ndim > 1 else 1
    fmt = ['%.15f'] * num_x_columns + ['%d']  # Adjust decimal places as needed for x

    # Create output file path in the csv directory with .csv extension
    output_csv = os.path.join(output_dir, os.path.basename(file_path).replace(".npz", ".csv"))

    # Save the combined array to CSV
    np.savetxt(output_csv, combined, delimiter=",", fmt=fmt)

    print(f"Data saved to {output_csv}")


npz_directory = "/home/a_ulrich/source/forest/example/data/adbench/npz"
output_dir = "/home/a_ulrich/source/forest/example/data/adbench/csv"

for file_path in pathlib.Path(npz_directory).glob('*.npz'):
    npz_to_csv_with_format(file_path, output_dir)
