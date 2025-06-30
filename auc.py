import matplotlib.pyplot as plt
import pandas as pd
import os

# Složka s CSV soubory
csv_folder = "csv/pokus_nove"

# Inicializace grafu
plt.figure()

# Projdi všechny CSV soubory ve složce
for file in os.listdir(csv_folder):
    if file.endswith(".csv"):
        file_path = os.path.join(csv_folder, file)

        # Načtení dat
        data = pd.read_csv(file_path, header=None, names=["FPR", "TPR"])

        # Vykreslení ROC křivky
        plt.plot(data["FPR"], data["TPR"], marker="o", linestyle="-", markersize=1, label=file)

# Přidání referenční čáry náhodné klasifikace
plt.plot([0, 1], [0, 1], "r--", label="Random Guess")

# Nastavení os a titulků
plt.xlabel("False Positive Rate (FPR)")
plt.ylabel("True Positive Rate (TPR)")
plt.title("ROC Curves for Multiple Models")
plt.legend(loc="center left", bbox_to_anchor=(1, 0.5))
plt.grid()

# Uložení a zobrazení grafu
plt.savefig("ROC_STARE2.svg", format="svg", bbox_inches="tight")
plt.show()

print("done")
