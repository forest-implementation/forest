#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# TOTO SPUST KDYZ CHCES PDF GRAFY ROC PRO KAZDY DATASET
# MUSI TOMU PREDCHAZET SPUSTENI ELIXIR SKRIPTU:
# MIX_ENV=example mix run example/totospust.ex

import os
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl

# ============================================================
#  LaTeX/PGFPlots styling with fallback (same styling as before)
# ============================================================
try:
    mpl.rcParams.update({
        "text.usetex": True,
        "font.family": "serif",
        "font.size": 12,
        "axes.unicode_minus": False,

        "axes.linewidth": 0.8,
        "axes.labelsize": 13,
        "axes.labelpad": 4,
        "axes.grid": True,
        "grid.color": "0.8",
        "grid.linewidth": 0.7,
        "grid.alpha": 1.0,

        "xtick.labelsize": 12,
        "ytick.labelsize": 12,
        "xtick.direction": "in",
        "ytick.direction": "in",
        "xtick.minor.visible": False,
        "ytick.minor.visible": False,

        "legend.frameon": True,
        "legend.framealpha": 1.0,
        "legend.fancybox": False,
        "legend.edgecolor": "0.3",
    })
except Exception:
    mpl.rcParams.update({
        "text.usetex": False,
        "font.family": "serif",
        "font.size": 12,
    })

# -----------------------------
# Config
# -----------------------------
csv_folders = {
    "adjusted": "csv/adjusted",
    "mad": "csv/mad",
    "zscore_more_trees": "csv/zscore_more_trees",
}

method_colors = {
    "adjusted": "tab:blue",
    "mad": "tab:green",
    "zscore_more_trees": "tab:orange",
}

out_dir = "imagesoutput/comparison_latex"
os.makedirs(out_dir, exist_ok=True)

def add_right_center_legend(ax):
    ax.legend(
        loc="center left",
        bbox_to_anchor=(1.02, 0.5),
        borderaxespad=0.0,
        frameon=True,
        edgecolor="0.3",
    )

# -----------------------------
# Collect unique datasets
# -----------------------------
all_datasets = set()
for folder_path in csv_folders.values():
    for file in os.listdir(folder_path):
        if file.endswith(".csv"):
            dataset_name = "_".join(file.split("_")[:-1])
            all_datasets.add(dataset_name)

# -----------------------------
# Plot per dataset
# -----------------------------
for dataset_name in sorted(all_datasets):
    fig, ax = plt.subplots(figsize=(10, 5))

    for method, folder_path in csv_folders.items():
        matching_files = [file for file in os.listdir(folder_path) if file.startswith(dataset_name)]

        for file in sorted(matching_files):
            file_path = os.path.join(folder_path, file)
            remaining_part = file.split("_")[-1].replace(".csv", "")

            data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])

            #linestyle = "-" if method == "adjusted" else ("--" if method == "mad" else ":")
            mm = "adjusted box" if method == "adjusted" else ("MAD" if method == "mad" else "z-score")
            ax.plot(
                data["FPR"], data["TPR"],
                marker="o",
                markersize=1,
                linewidth=1.2,
                label=rf"{mm}",
                color=method_colors[method],
            )

    # Random baseline
    ax.plot([0, 1], [0, 1], linestyle="--", linewidth=0.5, label="Random Guess",color="black")

    # Axis labels (no title, consistent with your LaTeX style)
    ax.set_xlabel(r"False Positive Rate (FPR)")
    ax.set_ylabel(r"True Positive Rate (TPR)")

    # Grid + limits (keep ROC conventions)
    ax.grid(True)
    ax.set_xlim(0.0, 1.0)
    ax.set_ylim(0.0, 1.0)

    # Sort legend alphabetically and place to the right-center with frame
    handles, labels = ax.get_legend_handles_labels()
    pairs = sorted(zip(labels, handles), key=lambda x: x[0])
    if pairs:
        sorted_labels, sorted_handles = zip(*pairs)
        ax.legend(
            sorted_handles,
            sorted_labels,
            loc="center left",
            bbox_to_anchor=(1.02, 0.5),
            borderaxespad=0.0,
            frameon=True,
            edgecolor="0.3",
        )
    else:
        add_right_center_legend(ax)

    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, f"ROC_{dataset_name}.pdf"), format="pdf", bbox_inches="tight")
    plt.close(fig)

print("done")
