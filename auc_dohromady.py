import matplotlib.pyplot as plt
import pandas as pd
import os
import itertools

# Složky s CSV soubory
csv_folders = {"old_hacko": "csv/old_hacko", "nove_hacko": "csv/nove_hacko"}

# Definujeme širší paletu barev
color_palette = list(plt.cm.get_cmap("tab20").colors) + list(plt.cm.get_cmap("Set3").colors)
colors = {}
color_cycle = itertools.cycle(color_palette)  # Použijeme širší barevnou paletu

plt.figure(figsize=(8, 6))

# Uchováváme legendu pro seřazení
legend_labels = []

# Projdi všechny složky
for folder_label, folder_path in csv_folders.items():
    for file in os.listdir(folder_path):
        if file.endswith(".csv"):
            file_path = os.path.join(folder_path, file)
            
            # Extrahujeme základní název datasetu (odstraníme číslo na konci)
            dataset_name = "_".join(file.split("_")[:-1])
            remaining_part = file.split("_")[-1].replace(".csv", "")
            
            # Přiřaď barvu, pokud ještě nemáme
            if dataset_name not in colors:
                colors[dataset_name] = next(color_cycle)
            
            # Načtení dat
            data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])
            
            # Vykreslení ROC křivky
            linestyle = "-" if folder_label == "old_hacko" else "--"
            label = f"{dataset_name} ({folder_label}, {remaining_part})"
            plt.plot(data["FPR"], data["TPR"], linestyle=linestyle, marker="o", markersize=1, 
                     label=label, color=colors[dataset_name])
            
            legend_labels.append(label)

# Přidání referenční čáry náhodné klasifikace
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")
legend_labels.append("Random Guess")

# Nastavení os a titulků
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("ROC Curves for Multiple Models")

# Seřazení legendy podle abecedy
handles, labels = plt.gca().get_legend_handles_labels()
sorted_labels_handles = sorted(zip(labels, handles), key=lambda x: x[0])
sorted_labels, sorted_handles = zip(*sorted_labels_handles)
plt.legend(sorted_handles, sorted_labels, loc="center left", bbox_to_anchor=(1, 0.5))
plt.grid()

# Uložení a zobrazení grafu
plt.savefig("ROC_COMPARISON.svg", format="svg", bbox_inches="tight")
plt.show()

print("done")
