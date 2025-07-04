import matplotlib.pyplot as plt
import pandas as pd
import os

# Složky
roc_folder = "csv/pokus_nove"
points_folder = "csv/pokus_nove_body"

# Inicializace grafu
plt.figure()

# Pro mapování názvu souboru na barvu
color_cycle = plt.rcParams['axes.prop_cycle'].by_key()['color']
color_map = {}  # název souboru (bez přípony) -> barva

# Projdi všechny ROC CSV soubory
for idx, file in enumerate(os.listdir(roc_folder)):
    if file.endswith(".csv"):
        base_name = os.path.splitext(file)[0]
        roc_path = os.path.join(roc_folder, file)
        points_path = os.path.join(points_folder, file)

        # Načti ROC křivku
        roc_data = pd.read_csv(roc_path, header=None, names=["FPR", "TPR"])

        # Vyber barvu pro tento soubor
        color = color_cycle[idx % len(color_cycle)]
        color_map[base_name] = color

        # Vykresli ROC křivku
        plt.plot(
            roc_data["FPR"],
            roc_data["TPR"],
            marker="o",
            linestyle="-",
            markersize=1,
            label=base_name,
            color=color
        )

        # Pokud existují body, přidej je
        if os.path.exists(points_path):
            points_data = pd.read_csv(points_path, header=None, names=["FPR", "TPR"])
            plt.plot(
                points_data["FPR"],
                points_data["TPR"],
                marker="o",
    linestyle="None",
    markersize=7,
    markerfacecolor='white',
    markeredgecolor=color,
    markeredgewidth=1.5,
    label=f"{base_name} points"
            )

# Referenční čára náhodné klasifikace
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")

# Nastavení os a legendy
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("ROC Curves for Multiple Models")
plt.legend(loc="center left", bbox_to_anchor=(1, 0.5))
plt.grid()

# Uložení a zobrazení
plt.savefig("ROC_STARE2.svg", format="svg", bbox_inches="tight")
plt.show()

print("done")
