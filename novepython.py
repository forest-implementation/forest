import matplotlib.pyplot as plt
import pandas as pd
import os

# Složky
#roc_folder = "csv/pokus_nove"
roc_folder = "csv/vybrane"
# points_folder = "csv/pokus_nove_body"
points_folder = "csv/vybrane_body"

# Inicializace grafu
plt.figure()

# Barvy pro jednotlivé křivky
color_cycle = plt.rcParams['axes.prop_cycle'].by_key()['color']
color_map = {}

# Najdi všechny ROC soubory ve složce
roc_files = [f for f in os.listdir(roc_folder) if f.startswith("roc_data") and f.endswith(".csv")]

for idx, file in enumerate(roc_files):
    roc_path = os.path.join(roc_folder, file)

    # Vyextrahuj suffix za "roc_data"
    suffix = file.replace("roc_data", "")  # např. "10_cover_0.5531682048297077.csv"
    base_label = suffix.replace(".csv", "")  # pro legendu

    # Cesty k bodům
    best_path = os.path.join(points_folder, f"roc_best_{suffix}")
    fixed_path = os.path.join(points_folder, f"roc_05_{suffix}")

    # Načti ROC křivku
    roc_data = pd.read_csv(roc_path, header=None, names=["FPR", "TPR"])

    # Barva
    color = color_cycle[idx % len(color_cycle)]
    color_map[base_label] = color

    # Vykresli ROC křivku
    plt.plot(
        roc_data["FPR"],
        roc_data["TPR"],
        marker="o",
        linestyle="-",
        markersize=1,
        label=base_label,
        color=color
    )

    # Vykresli nejlepší threshold (Youden)
    if os.path.exists(best_path):
        best = pd.read_csv(best_path, header=None, names=["FPR", "TPR"])
        fpr_val = best["FPR"].values[0]
        plt.plot(
            best["FPR"], best["TPR"],
            marker="o",
            linestyle="None",
            markersize=15,
            markerfacecolor='white',
            markeredgecolor=color,
            markeredgewidth=1.5,
            label=f"{base_label} best"
        )
        #plt.axvline(x=fpr_val, color='red', linestyle='--', linewidth=1)

    # Vykresli pevný threshold = 0.5
    if os.path.exists(fixed_path):
        fixed = pd.read_csv(fixed_path, header=None, names=["FPR", "TPR"])
        fpr_val = fixed["FPR"].values[0]
        plt.plot(
            fixed["FPR"], fixed["TPR"],
            marker="x",
            linestyle="None",
            markersize=15,
            color=color,
            label=f"{base_label} @ 0.5"
        )
        #plt.axvline(x=fpr_val, color='green', linestyle=':', linewidth=1)

# Referenční čára (náhodná klasifikace)
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")

# Osy, legenda, vzhled
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("ROC křivky s vyznačenými prahy")
plt.legend(loc="center left", bbox_to_anchor=(1, 0.5))
plt.grid(True)

# Uložení a zobrazení
plt.savefig("ROC_VSECHNO.svg", format="svg", bbox_inches="tight")
plt.show()

print("done")
