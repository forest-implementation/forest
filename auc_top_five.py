# python auc_top_five.py 

import matplotlib.pyplot as plt
import pandas as pd
import os
import numpy as np

# 📂 Složka s CSV soubory
csv_folder = "csv/"

# 📊 Funkce pro výpočet AUC (trapezoidální pravidlo)
def compute_auc(fpr, tpr):
    return np.trapz(tpr, fpr)  # Integrace pod křivkou

# 🔍 Seznam souborů ve složce
roc_curves = []

for file in os.listdir(csv_folder):
    if file.endswith(".csv"):
        file_path = os.path.join(csv_folder, file)

        # Načtení dat
        data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])

        # Výpočet AUC
        auc_value = compute_auc(data["FPR"], data["TPR"])
        
        # Uložení křivky a AUC hodnoty
        roc_curves.append((file, data, auc_value))

# 📌 Seřadíme podle AUC a vybereme 5 nejlepších
roc_curves.sort(key=lambda x: x[2], reverse=True)
top_5 = roc_curves[:5]

# 🎨 Vykreslení
plt.figure(figsize=(8, 8))

for file, data, auc in top_5:
    plt.plot(data["FPR"], data["TPR"], marker="o", linestyle="-",markersize=1, label=f"{file} (AUC={auc:.3f})")

# 🔹 Přidání referenční čáry
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")

# 🏷 Přizpůsobení popisků
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("Top 5 ROC Curves")
plt.grid()

# 📌 Legendu umístíme mimo graf
plt.legend(loc="center left", bbox_to_anchor=(1, 0.5))

# 📁 Uložení a zobrazení grafu
plt.savefig("top5_roc_curves.png", bbox_inches="tight")
plt.show()
