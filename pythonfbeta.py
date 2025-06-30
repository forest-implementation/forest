import os
import pandas as pd
import matplotlib.pyplot as plt
import itertools

# Define the folder containing CSV files
folder_path = "csv/fbeta_new"
output_svg = "fbeta_plot_new_c_16depth.svg"

# Check if folder exists
if not os.path.exists(folder_path):
    raise FileNotFoundError(f"Folder '{folder_path}' not found.")

# Define different line styles to improve diversity
line_styles = ['-', '--', '-.', ':']
line_cycle = itertools.cycle(line_styles)

# Read and process CSV files
data_frames = []
for file in os.listdir(folder_path):
    if file.endswith(".csv"):
        file_path = os.path.join(folder_path, file)
        df = pd.read_csv(file_path)
        if df.shape[1] >= 2:
            df_filtered = df[df.iloc[:, 0] < 1]  # Filter data until first column reaches 1
            x_values = df_filtered.iloc[:, 0]
            y_values = df_filtered.iloc[:, -1]
            data_frames.append((x_values, y_values, file, next(line_cycle)))

# Plot the data
plt.figure(figsize=(10, 6))
for x, y, label, style in data_frames:
    plt.plot(x, y, linestyle=style, linewidth=0.8, label=label)  # Thin lines with different styles

plt.xlabel("X-axis (First column)")
plt.ylabel("Y-axis (Last column)")
plt.title("F-Beta Score Plot")
plt.legend(loc='center left', bbox_to_anchor=(1, 0.5))  # Move legend to the right
plt.grid(True)

# Save as SVG
plt.savefig(output_svg, format='svg', bbox_inches='tight')
plt.close()

print(f"Plot saved as {output_svg}")