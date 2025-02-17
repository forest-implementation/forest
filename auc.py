import matplotlib.pyplot as plt
import pandas as pd
import os

# Složka s CSV soubory
csv_folder = "csv/"

# Inicializace grafu
plt.figure(figsize=(8, 8))

# Projdi všechny CSV soubory ve složce
for file in os.listdir(csv_folder):
    if file.endswith(".csv"):
        file_path = os.path.join(csv_folder, file)

        # Načtení dat
        data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])

        # Vykreslení ROC křivky
        plt.plot(data["FPR"], data["TPR"], marker="o", linestyle="-", label=file)

# Přidání referenční čáry náhodné klasifikace
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")

# Nastavení os a titulků
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("ROC Curves for Multiple Models")
plt.grid()

# Uložení a zobrazení grafu
plt.savefig("roc_curves.png")
plt.show()
