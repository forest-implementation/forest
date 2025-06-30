import matplotlib.pyplot as plt
import pandas as pd
import os
import itertools

# Složky s CSV soubory
csv_folders = {"adjusted": "csv/adjusted", "mad": "csv/mad", "zscore_more_trees": "csv/zscore_more_trees"}

# Definujeme barvy pro metody
method_colors = {"adjusted": "tab:blue", "mad": "tab:green", "zscore_more_trees": "tab:orange"}

# Získáme seznam unikátních datasetů
all_datasets = set()
for folder_path in csv_folders.values():
    for file in os.listdir(folder_path):
        if file.endswith(".csv"):
            dataset_name = "_".join(file.split("_")[:-1])
            all_datasets.add(dataset_name)

# Pro každý dataset vytvoříme graf se třemi metodami
for dataset_name in all_datasets:
    plt.figure(figsize=(8, 6))
    
    for method, folder_path in csv_folders.items():
        matching_files = [file for file in os.listdir(folder_path) if file.startswith(dataset_name)]
        
        for file in matching_files:
            file_path = os.path.join(folder_path, file)
            remaining_part = file.split("_")[-1].replace(".csv", "")
            
            # Načtení dat
            data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])
            
            # Vykreslení ROC křivky
            linestyle = "-" if method == "adjusted" else ("--" if method == "mad" else ":")
            plt.plot(data["FPR"], data["TPR"], linestyle=linestyle, marker="o", markersize=1, 
                     label=f"{method} ({remaining_part})", color=method_colors[method])
    
    # Přidání referenční čáry náhodné klasifikace
    plt.plot([0, 1], [0, 1], "r--", label="Random Guess")
    
    # Nastavení os a titulků
    plt.xlabel("False Positive Rate (FPR)")
    plt.ylabel("True Positive Rate (TPR)")
    plt.title(f"ROC Curves for {dataset_name}")

    # Seřazení legendy podle abecedy
    handles, labels = plt.gca().get_legend_handles_labels()
    sorted_labels_handles = sorted(zip(labels, handles), key=lambda x: x[0])
    sorted_labels, sorted_handles = zip(*sorted_labels_handles)
    plt.legend(sorted_handles, sorted_labels, loc="center left", bbox_to_anchor=(1, 0.5))
    plt.grid()

    # Uložení grafu
    plt.savefig(f"imagesoutput/comparison/ROC_{dataset_name}.svg", format="svg", bbox_inches="tight")
    plt.close()

print("done")
